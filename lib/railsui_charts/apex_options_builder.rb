# frozen_string_literal: true

module RailsuiCharts
  class ApexOptionsBuilder
    SUPPORTED_TYPES = %i[line area bar column sparkline pie donut scatter bubble radar polar_area range_bar].freeze

    # Bars never fill their band. The leftover space is what keeps a chart quiet,
    # so thickness scales down as the category count drops.
    BAR_THICKNESS = [[3, "30%"], [6, "42%"], [12, "58%"]].freeze
    DEFAULT_BAR_THICKNESS = "70%"

    # Series that support an overlaid previous-period comparison.
    COMPARABLE_TYPES = %i[line area column sparkline].freeze

    # Both sides of a dual axis are cut into this many intervals, so one grid
    # serves both scales.
    LEGEND_INSET = 28
    LEGEND_ITEM_GAP = 8
    LEGEND_MOBILE_ITEM_GAP = 6
    AXIS_INTERVALS = 4

    # Apex reserves a gutter between the axis labels and the edge of its canvas.
    # On its own that is invisible; inside a card it is not, because the card's
    # heading starts at the content edge and the axis labels start this far
    # inside it. Cancelling it lines the chart up with the text above it.
    AXIS_LABEL_GUTTER = 16

    # A category axis reserves almost nothing, because Apex sizes that column to
    # the text itself — the only thing outside it is the grid's own left
    # padding. Cancelling the full gutter here pushed the longest name twelve
    # pixels past the edge of the card.
    CATEGORY_AXIS_GUTTER = 4

    # Two rows' worth. Circular charts cap at four categories, which is the most
    # that can wrap onto a second line in a narrow card.
    CIRCULAR_LEGEND_HEIGHT = 52

    # No points, or points that carry no value. A series of zeroes is real data
    # and is not blank — a quiet day still has something to say.
    def self.blank?(data)
      return true if data.nil?
      return data.all? { |series| blank?(series[:data] || series["data"]) } if series_form?(data)

      points = data.respond_to?(:to_a) && !data.is_a?(Array) ? data.to_a : Array(data)
      return true if points.empty?

      points.all? { |point| value_of(point).nil? }
    end

    def self.value_of(point)
      case point
      when Hash
        point = point.symbolize_keys if point.respond_to?(:symbolize_keys)
        # A span carries its value in its edges rather than in a `y`. Without
        # this a timeline looks empty to `blank?` and renders the empty state
        # instead of itself — data present, chart gone, nothing raised.
        return point[:from] || point[:to] if point.key?(:from) || point.key?(:to)

        point[:y]
      when Array then point[1]
      else point
      end
    end

    def initialize(data, type: :line, compare: nil, **options)
      @series = extract_series(data)
      @data = @series.first[:data]
      @compare = compare.nil? ? nil : normalize_data(compare)
      @type = validate_type(type)
      @options = options
    end

    # A single series can be given bare; several arrive as an array of
    # `{ name:, data: }`. The `data` key is what tells the two apart, since a
    # bare series is an array of values or of `{ x:, y: }` points.
    def self.series_form?(data)
      data.is_a?(Array) && data.any? &&
        data.all? { |entry| entry.is_a?(Hash) && (entry.key?(:data) || entry.key?("data")) }
    end

    def build
      config = deep_merge(base_options, chart_specific_options, comparison_options, multi_series_options, stacked_options, user_options)
      return config if sparkline?

      # Derived from the finished config, not from the defaults. Apex swaps a
      # breakpoint's axis object in wholesale rather than merging it, so
      # anything already decided — which side the scale hangs on, hidden
      # labels — has to be carried across or it is lost at that width.
      config.merge(responsive: responsive_options(config))
    end

    private

    # Rails UI Charts Pro registers the forms this gem does not model, so a
    # treemap arrives here as a first-class type rather than as raw Apex config
    # smuggled past the builder.
    def validate_type(type)
      type = type.to_sym
      allowed = SUPPORTED_TYPES + RailsuiCharts.config.extra_types
      raise ArgumentError, "Unsupported chart type: #{type}. Supported: #{allowed.join(', ')}" unless allowed.include?(type)

      type
    end

    def extract_series(data)
      return [{ name: nil, data: normalize_data(data) }] unless self.class.series_form?(data)

      data.map do |entry|
        entry = entry.symbolize_keys if entry.respond_to?(:symbolize_keys)

        {
          name: entry[:name],
          data: normalize_data(entry[:data]),
          # A series may carry its own shape, scale, and formatting. Together
          # these are what makes a combo: revenue as columns against money on
          # the left, a churn rate as a line against percent on the right.
          type: entry[:type]&.to_sym,
          axis: entry[:axis]&.to_sym,
          format: entry[:format]&.to_sym
        }
      end
    end

    def multi?
      @series.length > 1
    end

    # One chart drawing more than one shape. Any series naming its own type
    # makes it so — there is no separate `type: :combo` to remember, because
    # the series already say what they are.
    def combo?
      @series.any? { |series| series[:type].present? }
    end

    def complex_combo?
      combo? && @series.each_with_index.any? do |series, index|
        RailsuiCharts.config.complex_point_types.include?(series_point_type(series, index))
      end
    end

    def dual_axis?
      @series.any? { |series| series[:axis] == :right }
    end

    def series_type(series, index)
      type = series[:type] || (index.zero? ? @type : @series.first[:type]) || @type
      apex_type_for(type)
    end

    def all_points
      @series.flat_map { |series| series[:data] }
    end

    def normalize_data(data)
      data = data.to_a if data.respond_to?(:to_a) && !data.is_a?(Array)

      data.map do |point|
        case point
        when Hash
          point = point.symbolize_keys if point.respond_to?(:symbolize_keys)
          normalized = { x: point[:x], y: span_or_value(point), z: point[:z] }
          normalized[:meta] = point[:meta] if point.key?(:meta)
          normalized[:name] = point[:name] if point.key?(:name)
          normalized[:label] = point[:label] if point.key?(:label)
          normalized[:v] = point[:v] if point.key?(:v)
          normalized[:points] = point[:points] if point.key?(:points)
          normalized
        when Array
          { x: point[0], y: point[1], z: point[2] }
        else
          { x: nil, y: point, z: nil }
        end
      end
    end

    # A range takes two values rather than one. `from:` and `to:` read better
    # than a bare two-element array at the call site, which is what a timeline
    # is written with, so both arrive here as the pair Apex wants.
    def span_or_value(point)
      return [point[:from], point[:to]] if point.key?(:from) || point.key?(:to)

      point[:y]
    end

    def categories
      return category_union if misaligned_series?

      @data.map { |d| d[:x] }.compact
    end

    # The union of every series' labels, in the order they first appear.
    #
    # Categories used to be read off the first series alone, and every later
    # series was then flattened to bare values and drawn from position zero.
    # For series that share an x-axis — the ordinary case — that is the same
    # thing. For series that do not, it silently plotted them in the wrong
    # place: a projection labelled November landed on January, on top of the
    # history it was meant to continue.
    def category_union
      # A caller who states the axis gets it. Series order decides first
      # appearance otherwise, and that is not always the reading order: a
      # forecast draws its band first so it sits behind the lines, which would
      # otherwise put next November before last January.
      @category_union ||= Array(@options[:categories]).presence ||
                          @series.flat_map { |series| series_labels(series) }.uniq
    end

    # Only when the series genuinely disagree. A series of bare values carries
    # no labels to align on, and aligning identical label lists would be the
    # same list — so in both cases nothing changes.
    def misaligned_series?
      return @misaligned unless @misaligned.nil?

      @misaligned =
        if @series.length < 2
          false
        elsif @options[:categories].present?
          @series.all? { |series| series_labels(series).any? }
        else
          labels = @series.map { |series| series_labels(series) }
          labels.none?(&:empty?) && labels.uniq.length > 1
        end
    end

    def series_labels(series)
      Array(series[:data]).filter_map { |point| point[:x] if point.is_a?(Hash) }
    end

    # A bare array of values carries no labels, and Apex sizes the x-axis from
    # this list: given an empty one it draws nothing at all — no canvas, no
    # error, just an element that stays empty. Positions stand in, which is
    # what the accessibility table already does for exactly this data.
    #
    # Only the axis needs this. Circular types name their own slices, and
    # handing them numbers would replace "Item 1" with "1".
    def axis_categories
      # A lane per label, not per span. Two spans on one row is the whole point
      # of a timeline, and Apex draws both of them in the first matching lane
      # either way — but left to derive the list itself it also reserves a
      # second, empty lane underneath and labels it the same.
      return categories.uniq if timeline?
      return categories if categories.any? || @data.empty?

      @data.each_index.map { |index| index + 1 }
    end

    def series_values
      @data.map { |d| d[:y] }
    end

    def scatter_series
      @data.map { |d| [d[:x], d[:y]] }
    end

    def bubble_series
      @data.map { |d| { x: d[:x], y: d[:y], z: d[:z] || 1 } }
    end

    def base_options
      {
        chart: {
          type: apex_chart_type,
          height: @options[:height] || RailsuiCharts.config.default_height,
          toolbar: { show: false },
          animations: { enabled: true, easing: "easeinout", speed: 400 },
          parentHeightOffset: 0,
          # Apex observes the parent box and redraws on any change. Inside a
          # flex card the redraw can itself change that box, which spins into a
          # repaint loop. Window resizes still redraw.
          redrawOnParentResize: false,
          redrawOnWindowResize: true,
          fontFamily: font_family,
          background: "transparent"
        },
        series: series_for_type,
        xaxis: xaxis_options,
        yaxis: yaxis_options,
        grid: grid_options,
        colors: colors_for_type,
        dataLabels: { enabled: false },
        stroke: stroke_options,
        fill: fill_options,
        markers: marker_options,
        legend: { show: false },
        # Apex darkens the whole mark on hover by default, which reads as a blob.
        # The crosshair and tooltip carry the hover state instead.
        states: {
          hover: { filter: { type: "none" } },
          active: { filter: { type: "none" } }
        },
        tooltip: tooltip_options,
        theme: { mode: "light" }
      }
    end

    # A chart that only works at desktop width is not finished. On a phone the
    # plot loses most of its horizontal room, so the chrome gives way first:
    # fewer gridlines, smaller type, a tighter legend, and less height.
    def responsive_options(config)
      [
        {
          breakpoint: 640,
          options: {
            chart: { height: mobile_height },
            # A tighter item gap needs a matching correction, or the mobile
            # legend lands two pixels left of where the desktop one does.
            legend: {
              fontSize: font_size_sm,
              itemMargin: { horizontal: LEGEND_MOBILE_ITEM_GAP, vertical: 2 },
              offsetX: legend_offset(LEGEND_MOBILE_ITEM_GAP)
            },
            xaxis: carry_over(config[:xaxis], { labels: { style: { fontSize: font_size_sm } } }),
            yaxis: mobile_yaxis(config[:yaxis]),
            grid: carry_over(config[:grid], { padding: { left: 0, right: 0 } }),
            markers: { hover: { size: 8 } }
          }
        }
      ]
    end

    def mobile_yaxis(current)
      # A chart with more than one scale carries an axis object per series, and
      # the whole array has to survive the breakpoint. Handing it to carry_over
      # would return the bare overrides instead, because an Array is not a Hash
      # — every seriesName mapping goes with it, and Apex falls back to drawing
      # all of the series against a single scale. On an OHLC chart that puts
      # price on the volume axis, where candles in the hundreds against volume
      # in the tens of thousands flatten into a line on the baseline.
      #
      # Each axis is judged on its own, since the tick count below turns on
      # bounds this axis in particular may have been given.
      return current.map { |axis| mobile_yaxis(axis) } if current.is_a?(Array)

      overrides = { labels: { style: { fontSize: font_size_sm } } }
      # A numeric axis already has bounds picked so its ticks land on round
      # numbers. Forcing a count knocks them back off — 10..70 in four steps
      # reads 10 / 25 / 40 / 55 / 70.
      overrides[:tickAmount] = 4 unless current.is_a?(Hash) && current.key?(:min)

      carry_over(current, overrides)
    end

    def carry_over(current, overrides)
      current.is_a?(Hash) ? deep_merge(current, overrides) : overrides
    end

    def mobile_height
      height = @options[:height] || RailsuiCharts.config.default_height
      [height.to_i, 260].min
    end

    def chart_specific_options
      case @type
      when :sparkline
        {
          chart: { sparkline: { enabled: true } },
          grid: { show: false },
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } }
        }
      when :bar
        { plotOptions: { bar: bar_plot_options.merge(horizontal: true, barHeight: bar_thickness) } }
      when :column
        { plotOptions: { bar: bar_plot_options.merge(horizontal: false, columnWidth: bar_thickness) } }
      when :range_bar
        {
          # Horizontal because a timeline reads left to right, and because the
          # row labels are names rather than a scale — vertical would rotate
          # them.
          plotOptions: { bar: { horizontal: true, borderRadius: geometry(:bar_radius), barHeight: bar_thickness } },
          xaxis: { type: "datetime" },
          # The bar already spans its own dates. A gridline behind every row
          # would be drawing the categories twice.
          grid: { yaxis: { lines: { show: false } }, xaxis: { lines: { show: true } } },
          tooltip: { x: { format: "d MMM yyyy" } }
        }
      when :pie, :donut
        {
          labels: circular_labels,
          plotOptions: circular_plot_options,
          dataLabels: { enabled: false },
          legend: circular_legend,
          stroke: { show: true, width: 2, colors: [surface_color] },
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } },
          grid: { show: false }
        }
      when :scatter
        {
          markers: { size: 6, strokeWidth: 2, strokeColors: surface_color, hover: { size: 8 } },
          xaxis: numeric_axis(:x),
          yaxis: numeric_axis(:y)
        }
      when :bubble
        {
          plotOptions: { bubble: { zScaling: true, minBubbleRadius: 6, maxBubbleRadius: 28 } },
          markers: { strokeWidth: 0 },
          fill: { opacity: 0.75 },
          xaxis: numeric_axis(:x),
          yaxis: numeric_axis(:y)
        }
      when :radar
        {
          markers: { size: 4, strokeWidth: 0, hover: { size: 6 } },
          stroke: { curve: "straight", width: 2, colors: [config_color(:primary)] },
          fill: { opacity: 0.12, colors: [config_color(:primary)] },
          plotOptions: { radar: radar_plot_options },
          xaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: font_family, fontSize: font_size } } },
          # The concentric rings already carry magnitude; a numeric axis just
          # overprints the polygon.
          yaxis: { show: false },
          # The radar's own polygons are the grid. Leaving the cartesian grid on
          # rules horizontal lines straight through the shape.
          grid: { show: false }
        }
      when :polar_area
        {
          labels: circular_labels,
          plotOptions: { polarArea: { rings: { strokeWidth: 1, strokeColor: config_color(:grid) }, spokes: { strokeWidth: 1, connectorColors: config_color(:grid) } } },
          dataLabels: { enabled: false },
          legend: circular_legend,
          stroke: { show: true, width: 2, colors: [surface_color] },
          xaxis: { labels: { show: false } },
          yaxis: { show: false },
          grid: { show: false }
        }
      else
        {}
      end
    end

    # A previous-period series rides underneath the current one as a dashed,
    # muted line. Identity comes from the tooltip labels and the legend, never
    # from the colour alone.
    def comparison_options
      return {} unless comparing?

      {
        colors: [config_color(:primary), config_color(:muted)],
        stroke: {
          curve: curve,
          # Both periods take the same weight; the dash is what separates them,
          # so thinning the comparison would say "less important" twice.
          width: [geometry(:stroke_width), geometry(:stroke_width)],
          dashArray: [0, 4]
        },
        fill: comparison_fill,
        tooltip: { shared: true, intersect: false },
        legend: comparison_legend,
        # The comparison series plots against the current period's x positions,
        # so its own dates would otherwise be lost. The tooltip wants them: a
        # row reading "Aug 4" says more than a second row reading "Aug 11".
        compare_categories: @compare.map { |point| point[:x] }.compact
      }
    end

    # Two or more series always carry a legend. Colour alone is never the only
    # thing telling them apart.
    def multi_series_options
      return {} unless multi?

      options = { legend: series_legend, tooltip: { shared: true, intersect: false } }
      return options unless combo?

      # Read by the Stimulus controller, not by Apex. A combo puts money on one
      # row of the tooltip and a percentage on the next, and a single formatter
      # across both dresses one of them wrongly.
      options[:series_formats] = @series.map { |series| series[:format] || @options[:format] || :number }
      options
    end

    # Stacking answers "what is this made of over time", which a grouped chart
    # cannot. `stacked: :percent` switches from totals to share.
    def stacked_options
      return {} unless @options[:stacked]

      {
        chart: { stacked: true, stackType: @options[:stacked].to_s == "percent" ? "100%" : "normal" },
        # Segments separate with a gap in the surface colour rather than a
        # stroke drawn around them, so the divider never reads as data.
        stroke: { show: true, width: 2, colors: [surface_color] },
        plotOptions: { bar: { borderRadius: geometry(:bar_radius), borderRadiusApplication: "end" } }
      }
    end

    def series_legend
      {
        show: true,
        position: "top",
        horizontalAlign: "left",
        offsetX: legend_offset(LEGEND_ITEM_GAP),
        fontFamily: font_family,
        fontSize: font_size,
        labels: { colors: config_color(:text) },
        markers: { width: 8, height: 8, radius: 8, offsetX: -2 },
        itemMargin: { horizontal: LEGEND_ITEM_GAP, vertical: 0 }
      }
    end

    # Left-aligning the legend does not put it where the eye expects. Apex
    # insets it by its own chrome and padding before the first item's margin is
    # even applied, so the markers sit indented from the axis labels and the
    # heading above them — every other line in the card starts at one edge and
    # the legend starts somewhere else.
    #
    # Measured against a rendered chart rather than derived: at offsetX 0 the
    # marker lands LEGEND_INSET + the item gap to the right of the card edge,
    # and the correction is linear in offsetX.
    def legend_offset(item_gap)
      -(LEGEND_INSET + item_gap)
    end

    def comparison_fill
      # The comparison series gets a flat gradient rather than `opacity: 0`,
      # which would take its stroke down with it.
      if @type == :area
        return {
          type: "gradient",
          gradient: { shadeIntensity: 1, opacityFrom: [0.16, 0], opacityTo: [0, 0], stops: [0, 100] }
        }
      end

      return { opacity: [1, 0.35] } if @type == :column

      { opacity: [1, 1] }
    end

    def comparison_legend
      return { show: false } if sparkline?

      series_legend
    end

    def comparing?
      !@compare.nil? && !@compare.empty? && !multi? && COMPARABLE_TYPES.include?(@type)
    end

    def bar_plot_options
      {
        borderRadius: geometry(:bar_radius),
        # Round the data-end only; the baseline stays square so every bar
        # grows from the same edge.
        borderRadiusApplication: "end",
        dataLabels: { position: "top" }
      }
    end

    def bar_thickness
      count = [@data.size, 1].max
      match = BAR_THICKNESS.find { |max, _| count <= max }
      match ? match.last : DEFAULT_BAR_THICKNESS
    end

    def radar_plot_options
      {
        polygons: {
          strokeColors: config_color(:grid),
          connectorColors: config_color(:grid),
          fill: { colors: ["transparent"] }
        }
      }
    end

    def circular_labels
      categories.any? ? categories : @data.map.with_index { |_, i| "Item #{i + 1}" }
    end

    def circular_plot_options
      case @type
      when :donut
        { pie: { donut: { size: "62%", labels: { show: false } }, expandOnClick: false } }
      when :pie
        { pie: { offsetX: 0, offsetY: 0, expandOnClick: false } }
      else
        {}
      end
    end

    def circular_legend
      {
        show: true,
        position: "bottom",
        horizontalAlign: "center",
        fontFamily: font_family,
        fontSize: font_size,
        # Reserve the band rather than letting Apex estimate it. Its own
        # estimate runs a few pixels short, and since the canvas clips, the
        # bottom row of labels loses its descenders — or the whole row, once a
        # narrow card wraps the legend onto two lines.
        height: CIRCULAR_LEGEND_HEIGHT,
        itemMargin: { horizontal: 8, vertical: 2 },
        labels: { colors: config_color(:text) },
        markers: { width: 8, height: 8, radius: 8, offsetX: -2 }
      }
    end

    def series_for_type
      return series_values if circular?

      plotted = @series.each_with_index.map do |series, index|
        point_type = series_point_type(series, index)
        entry = { name: series[:name] || (index.zero? ? series_label : "Series #{index + 1}"), data: points_for(series[:data], point_type) }
        # Only on a combo. Naming a type on every series of an ordinary chart
        # would override the chart-level one and quietly ignore `type:`.
        entry[:type] = apex_type_for(point_type) if combo?
        entry
      end

      comparing? ? plotted + [{ name: compare_label, data: @compare.map { |point| point[:y] } }] : plotted
    end

    def series_point_type(series, index)
      (series[:type] || (index.zero? ? @type : @series.first[:type]) || @type).to_sym
    end

    def points_for(points, point_type = @type)
      case point_type
      when :scatter then points.map { |point| [point[:x], point[:y]] }
      when :bubble then points.map { |point| { x: point[:x], y: point[:y], z: point[:z] || 1 } }
      when :range_bar
        # Both ends stay in the point. A range read off an axis is only half a
        # range, and the label names the row rather than a position on a scale.
        points.map do |point|
          range = { x: point[:x], y: Array(point[:y]).map { |edge| range_edge(edge) } }
          range[:meta] = point[:meta] if point.key?(:meta)
          range[:name] = point[:name] if point.key?(:name)
          range
        end
      else
        # A registered type may draw its own labels rather than read them off an
        # axis, in which case flattening the point to a value loses them.
        return points.map { |point| preserved_point(point) } if preserved_points?(point_type) || preserve_combo_points?(points)
        return aligned_values(points) if misaligned_series?

        points.map { |point| point[:y] }
      end
    end

    # A slot per shared category, nil where this series has nothing. Apex draws
    # a nil as a gap, which is what a forecast that begins after the history
    # ends should look like.
    def aligned_values(points)
      lookup = points.each_with_object({}) do |point, memo|
        memo[point[:x]] = point[:y] if point.is_a?(Hash)
      end

      category_union.map { |category| lookup[category] }
    end

    def preserve_combo_points?(points)
      complex_combo? && points.any? { |point| point[:x].present? }
    end

    def preserved_points?(type)
      RailsuiCharts.config.labelled_point_types.include?(type) ||
        RailsuiCharts.config.complex_point_types.include?(type)
    end

    def preserved_point(point)
      point.slice(:x, :y, :z, :meta, :name, :label, :v, :points).compact
    end

    # Apex plots a range against a time axis in milliseconds. Handing it a Time
    # gives "Invalid Date" rather than an error, so the conversion happens here
    # where the type is known and a plain number is still allowed through for
    # a range that is not about time at all.
    def range_edge(value)
      return value.to_time.to_i * 1000 if value.respond_to?(:to_time)

      value
    end

    def timeline?
      @type == :range_bar
    end

    def series_label
      @options[:label] || "Value"
    end

    def compare_label
      @options[:compare_label] || "Previous period"
    end

    def xaxis_options
      return { labels: { show: false } } if circular?
      return numeric_axis(:x) if numeric_xaxis?

      options = {
        categories: axis_categories,
        labels: {
          show: categories.any? && !sparkline?,
          style: { colors: config_color(:text), fontFamily: font_family, fontSize: font_size },
          # Rotated labels are the loudest tell of an unstyled chart. Labels
          # either fit horizontally or the tick count comes down.
          rotate: 0,
          rotateAlways: false,
          hideOverlappingLabels: true,
          trim: false
        },
        axisBorder: { show: false },
        axisTicks: { show: false },
        crosshairs: crosshair_options,
        tooltip: { enabled: false },
        type: "category"
      }

      # A complex combo carries its own x in every point, and a derived category
      # list alongside numeric pair data makes Apex plot nothing. An explicit
      # one is different: Apex reads xaxis.categories ahead of everything else,
      # and without it a combo takes its whole axis from the first series alone
      # — which draws every other series from position zero.
      options = options.except(:categories) if complex_combo? && @options[:categories].blank?
      options
    end

    # Scatter and bubble plot real x values. Handing Apex a `categories` array
    # alongside numeric pair data makes it plot nothing at all, so the numeric
    # axis is built without one.
    def numeric_axis(axis)
      base = {
        labels: {
          show: true,
          style: { colors: config_color(:text), fontFamily: font_family, fontSize: font_size }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      }

      # Bubbles get a whole step of headroom because their radius is drawn
      # around the point. Scatter dots are small enough that pixel padding on
      # the grid keeps them clear of the axis without distorting the ticks.
      bounds = nice_bounds(all_points.map { |point| point[axis] }, 5, pad: bubble?)

      if axis == :x
        return base.merge(bounds_for(bounds, :x), type: "numeric", crosshairs: crosshair_options, tooltip: { enabled: false })
      end

      base.merge(bounds_for(bounds, :y))
    end

    # Apex counts ticks differently per axis: a numeric x-axis renders
    # `tickAmount + 2` labels (so it cuts the range into `tickAmount + 1`
    # intervals), while the y-axis renders `tickAmount + 1`. Feeding both the
    # same number is what puts x-ticks on values like 14.2.
    def bounds_for(bounds, axis)
      return { tickAmount: bounds[:intervals] } unless bounds.key?(:min)

      intervals = bounds[:intervals]
      {
        min: bounds[:min],
        max: bounds[:max],
        tickAmount: axis == :x ? [intervals - 1, 1].max : intervals,
        decimalsInFloat: bounds[:decimals]
      }
    end

    # Apex splits a numeric range into equal parts, which lands ticks on values
    # like 13.6 and 17.2. Snapping the bounds outward to a round step puts them
    # back on numbers a reader can hold in their head.
    def nice_bounds(values, target_intervals, pad: false)
      values = values.compact.map(&:to_f)
      return { intervals: target_intervals } if values.empty?

      min, max = values.minmax
      return { intervals: target_intervals } if min == max

      step = nice_step((max - min) / target_intervals.to_f)
      low = (min / step).floor * step
      high = (max / step).ceil * step

      # Bubbles are drawn around their point, so a mark sitting on the boundary
      # gets sliced in half by the plot edge.
      if pad
        low -= step
        high += step
      end

      {
        min: trim_float(low),
        max: trim_float(high),
        intervals: ((high - low) / step).round,
        decimals: step == step.to_i ? 0 : 1
      }
    end

    def nice_step(raw)
      return 1 if raw <= 0

      magnitude = 10.0**Math.log10(raw).floor
      [1, 2, 2.5, 5].each { |multiple| return multiple * magnitude if raw <= multiple * magnitude }
      10 * magnitude
    end

    def trim_float(value)
      value == value.to_i ? value.to_i : value.round(4)
    end

    def crosshair_options
      return { show: false } if sparkline?

      {
        show: true,
        stroke: { color: config_color(:grid), width: 1, dashArray: 0 }
      }
    end

    def yaxis_options
      return { labels: { show: false } } if circular?
      return dual_yaxis_options if dual_axis?

      {
        # Stripe-style dashboards hang the scale on the right so the plot starts
        # flush with the card's left edge.
        opposite: @options[:axis] == :right,
        labels: {
          show: !sparkline?,
          offsetX: axis_label_offset(@options[:axis] == :right),
          style: { colors: config_color(:text), fontFamily: font_family, fontSize: font_size }
        },
        tickAmount: 5,
        axisBorder: { show: false },
        axisTicks: { show: false }
      }
    end

    # Apex matches a yaxis array to the series by position, so there is one
    # entry per series whether or not it draws a scale.
    #
    # Only the first series on each side draws one. Two series sharing the left
    # scale would otherwise stack two identical rulers on top of each other,
    # which reads as a rendering fault rather than as two series.
    def dual_yaxis_options
      drawn = { left: false, right: false }
      scales = aligned_scales

      @series.each_with_index.map do |series, index|
        side = series[:axis] == :right ? :right : :left
        show = !drawn[side]
        drawn[side] = true

        {
          seriesName: series[:name] || (index.zero? ? series_label : "Series #{index + 1}"),
          opposite: side == :right,
          show: show,
          **scales.fetch(side, {}),
          # The reader has to know which scale belongs to which series, and on
          # a two-axis chart position alone does not say. The labels take the
          # colour of the series they measure.
          labels: {
            show: show,
            offsetX: axis_label_offset(side == :right),
            style: { colors: axis_ink(index), fontFamily: font_family, fontSize: font_size }
          },
          format: series[:format] || @options[:format],
          axisBorder: { show: false },
          axisTicks: { show: false }
        }.compact
      end
    end

    # Negative on both sides: Apex mirrors offsetX for an opposite axis, so the
    # same sign pulls each toward its own edge rather than one of them inward.
    # The right reserves two pixels less than the left, which is the axis border
    # allowance it draws on one side only.
    #
    # A y-axis carrying category names rather than values — a horizontal bar or
    # a timeline — reserves a different amount, so it gets its own figure.
    def axis_label_offset(opposite)
      return -CATEGORY_AXIS_GUTTER if category_yaxis?

      opposite ? -(AXIS_LABEL_GUTTER - 2) : -AXIS_LABEL_GUTTER
    end

    def category_yaxis?
      timeline? || @type == :bar
    end

    # Series colour belongs to the marks and legend. Keep both scales neutral
    # so the numbers stay readable and do not compete with the data.
    def axis_ink(_index)
      config_color(:text)
    end

    # Both sides fitted to their own values, then cut into the same number of
    # intervals — that shared count is what makes one set of gridlines serve
    # both scales.
    #
    # Apex's own forceNiceScale fits each axis independently and rounds hard:
    # revenue topping out at 52K came back as a 0–100K scale with the columns
    # filling half the plot while the line sat against a well-fitted one.
    def aligned_scales
      sides = %i[left right].to_h { |side| [side, fit_axis(axis_values(side))] }
      return {} unless sides.values.all?

      sides
    end

    # A scale fitted to its values in exactly AXIS_INTERVALS steps.
    #
    # The interval count is fixed rather than derived, because that is the
    # whole alignment mechanism: two axes cut into the same number of pieces
    # put their gridlines on each other whatever their ranges are.
    #
    # The step ladder is finer than the one a single axis uses. With a fixed
    # count, a coarse ladder is what produces the too-tall scale: revenue
    # topping out at 52K wants a step near 13K, and rounding that to 20K makes
    # a 0–100K axis with the columns filling half the plot.
    def fit_axis(values)
      values = values.compact.map(&:to_f)
      return nil if values.empty?

      min, max = values.minmax
      return nil if min == max

      step = dual_step((max - min) / AXIS_INTERVALS.to_f)
      # The floor moves down to a multiple of the step, which can leave the top
      # short. Widening the step is what recovers it.
      step = dual_step(step * 1.0001) while (min / step).floor * step + step * AXIS_INTERVALS < max

      low = (min / step).floor * step
      { min: trim_float(low), max: trim_float(low + step * AXIS_INTERVALS), tickAmount: AXIS_INTERVALS,
        decimalsInFloat: step == step.to_i ? 0 : 1 }
    end

    # 1.5 and 3 are on this ladder and not on nice_step's. They are the steps
    # that keep a fixed-count scale close to its data instead of doubling past
    # it.
    DUAL_STEPS = [1, 1.5, 2, 2.5, 3, 4, 5, 7.5].freeze

    # 10.0 and not 10: an Integer raised to a negative Integer gives a Rational
    # in Ruby, and a Rational survives every calculation below to arrive in the
    # browser as the string "5/2". Apex cannot read that, drops the bound, and
    # quietly auto-scales — which clipped the top of the data rather than
    # raising anything.
    def dual_step(raw)
      return 1 if raw <= 0

      magnitude = 10.0**Math.log10(raw).floor
      DUAL_STEPS.each { |multiple| return multiple * magnitude if raw <= multiple * magnitude }
      10 * magnitude
    end

    def axis_values(side)
      values = @series.select { |series| axis_side(series) == side }
                      .flat_map { |series| series[:data].flat_map { |point| Array(point[:y]) } }
      # A column grows from a baseline, so its scale has to contain one. A line
      # can float, and forcing zero on a churn rate hovering near 3% would
      # flatten it against the top of the plot.
      values << 0 if values.any? && baseline?(side)
      values
    end

    def axis_side(series)
      series[:axis] == :right ? :right : :left
    end

    def baseline?(side)
      @series.any? do |series|
        axis_side(series) == side && %w[bar column].include?((series[:type] || @type).to_s)
      end
    end

    def grid_options
      return { show: false } if circular? || sparkline?

      {
        show: true,
        borderColor: config_color(:grid),
        # Solid hairlines. Dashes read as "projection" or "threshold" when all
        # they are is a grid.
        strokeDashArray: 0,
        xaxis: { lines: { show: false } },
        yaxis: { lines: { show: true } },
        # Numeric plots put marks right on the boundary, so they need the marker
        # radius as breathing room on both sides.
        padding: numeric_xaxis? ? { top: 0, right: 12, bottom: 0, left: 12 } : { top: 0, right: 0, bottom: 0, left: 4 }
      }
    end

    def marker_options
      return { size: 0 } if sparkline?

      {
        size: geometry(:marker_size),
        strokeWidth: geometry(:stroke_width),
        strokeColors: surface_color,
        hover: { size: geometry(:marker_hover_size), sizeOffset: 0 }
      }
    end

    def tooltip_options
      {
        theme: "dark",
        shared: !circular?,
        intersect: false,
        followCursor: false,
        x: { show: !circular? && categories.any? },
        marker: { show: true },
        style: { fontFamily: font_family, fontSize: font_size }
      }
    end

    def colors_for_type
      return categorical_palette if circular? || radar? || bubble? || multi?
      [config_color(:primary)]
    end

    # Assigned in fixed order and never cycled: a fifth slice takes slot 5, not
    # slot 1 again. Callers past eight categories should fold the tail into an
    # "Other" bucket rather than repeat a hue.
    def categorical_palette
      RailsuiCharts.config.series_colors.map { |value| resolve_var(value) }
    end

    def radar?
      @type == :radar
    end

    def bubble?
      @type == :bubble
    end

    def curve
      @options[:curve] || "straight"
    end

    def stroke_options
      case @type
      when :sparkline
        { curve: curve, width: geometry(:stroke_width), lineCap: "round" }
      when :bar, :column
        { show: true, width: 0, colors: ["transparent"] }
      when :bubble
        { show: false }
      else
        { curve: curve, width: geometry(:stroke_width), lineCap: "round" }
      end
    end

    def fill_options
      case @type
      when :area
        {
          type: "gradient",
          gradient: {
            shadeIntensity: 1,
            # A wash, never a saturated block.
            opacityFrom: 0.16,
            opacityTo: 0.0,
            stops: [0, 100]
          }
        }
      else
        # Never zero. Apex derives a line's stroke alpha from fill.opacity, so
        # `opacity: 0` renders the line fully transparent.
        { opacity: 1 }
      end
    end

    def deep_merge(*hashes)
      hashes.each_with_object({}) do |hash, result|
        hash.each do |key, value|
          result[key] = if value.is_a?(Hash) && result[key].is_a?(Hash)
                          deep_merge(result[key], value)
                        else
                          value
                        end
        end
      end
    end

    def user_options
      opts = @options.except(:type, :height, :label, :compare, :compare_label, :curve, :axis, :accessible, :id)
      opts[:colors] = Array(opts[:colors]).map { |c| config_color(c) || c } if opts.key?(:colors)
      opts[:currency] ||= RailsuiCharts.config.default_currency if %w[currency short_currency].include?(opts[:format].to_s)
      opts
    end

    def apex_chart_type
      # A mixed chart takes its shape from each series, and Apex wants the
      # chart-level type to be "line" while they do — set to "bar" it draws
      # every series as bars whatever they asked for.
      if combo?
        complex = @series.map.with_index { |series, index| series_point_type(series, index) }
                         .find { |type| RailsuiCharts.config.complex_point_types.include?(type) }
        return apex_type_for(complex) if complex

        return "line"
      end

      apex_type_for(@type)
    end

    def apex_type_for(type)
      case type&.to_sym
      when :sparkline then "line"
      when :range_bar then "rangeBar"
      when :range_area then "rangeArea"
      when :box_plot then "boxPlot"
      when :column, :bar then "bar"
      when :donut then "donut"
      when :polar_area then "polarArea"
      else type.to_s
      end
    end

    def sparkline?
      @type == :sparkline
    end

    def circular?
      %i[pie donut polar_area].include?(@type)
    end

    def numeric_xaxis?
      %i[scatter bubble].include?(@type)
    end

    def config_color(key)
      RailsuiCharts.config.colors[key]
    end

    # Type ships as a `var()` string and is resolved in the browser, the same
    # way the colours are. Geometry cannot: Apex does arithmetic on a radius or
    # a stroke width, and a resolved variable would arrive as a string.
    def font_family
      RailsuiCharts.config.typography[:family]
    end

    def font_size
      RailsuiCharts.config.typography[:size]
    end

    def font_size_sm
      RailsuiCharts.config.typography[:size_sm]
    end

    def geometry(key)
      RailsuiCharts.config.geometry[key]
    end

    def surface_color
      RailsuiCharts.config.colors[:surface] || "var(--rui-chart-surface, #ffffff)"
    end

    def solid_color(key)
      resolve_var(config_color(key))
    end

    # Apex resolves multi-series colour arrays before the Stimulus controller
    # gets a chance to swap CSS variables in, so these slots ship as hex.
    def resolve_var(value)
      value = value.to_s
      return value unless value.start_with?("var(")

      value.match(/var\([^,]+,\s*([^)]+)\)/)&.captures&.first || value
    end
  end
end
