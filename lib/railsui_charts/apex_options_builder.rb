# frozen_string_literal: true

module RailsuiCharts
  class ApexOptionsBuilder
    SUPPORTED_TYPES = %i[line area bar column sparkline pie donut scatter bubble radar polar_area].freeze

    # Bars never fill their band. The leftover space is what keeps a chart quiet,
    # so thickness scales down as the category count drops.
    BAR_THICKNESS = [[3, "30%"], [6, "42%"], [12, "58%"]].freeze
    DEFAULT_BAR_THICKNESS = "70%"

    # Series that support an overlaid previous-period comparison.
    COMPARABLE_TYPES = %i[line area column sparkline].freeze

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
      when Hash then point[:y] || point["y"]
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
        { name: entry[:name] || entry["name"], data: normalize_data(entry[:data] || entry["data"]) }
      end
    end

    def multi?
      @series.length > 1
    end

    def all_points
      @series.flat_map { |series| series[:data] }
    end

    def normalize_data(data)
      data = data.to_a if data.respond_to?(:to_a) && !data.is_a?(Array)

      data.map do |point|
        case point
        when Hash
          { x: point[:x] || point["x"], y: point[:y] || point["y"], z: point[:z] || point["z"] }
        when Array
          { x: point[0], y: point[1], z: point[2] }
        else
          { x: nil, y: point, z: nil }
        end
      end
    end

    def categories
      @data.map { |d| d[:x] }.compact
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
          fontFamily: "inherit",
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
            legend: { fontSize: "11px", itemMargin: { horizontal: 6, vertical: 2 } },
            xaxis: carry_over(config[:xaxis], { labels: { style: { fontSize: "11px" } } }),
            yaxis: mobile_yaxis(config[:yaxis]),
            grid: carry_over(config[:grid], { padding: { left: 0, right: 0 } }),
            markers: { hover: { size: 8 } }
          }
        }
      ]
    end

    def mobile_yaxis(current)
      overrides = { labels: { style: { fontSize: "11px" } } }
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
          xaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit", fontSize: "12px" } } },
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
          width: sparkline? ? [2, 2] : [2, 2],
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

      { legend: series_legend, tooltip: { shared: true, intersect: false } }
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
        plotOptions: { bar: { borderRadius: 4, borderRadiusApplication: "end" } }
      }
    end

    def series_legend
      {
        show: true,
        position: "top",
        horizontalAlign: "left",
        offsetX: -8,
        fontFamily: "inherit",
        fontSize: "12px",
        labels: { colors: config_color(:text) },
        markers: { width: 8, height: 8, radius: 8, offsetX: -2 },
        itemMargin: { horizontal: 8, vertical: 0 }
      }
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
        borderRadius: 4,
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
        fontFamily: "inherit",
        fontSize: "12px",
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
        { name: series[:name] || (index.zero? ? series_label : "Series #{index + 1}"), data: points_for(series[:data]) }
      end

      comparing? ? plotted + [{ name: compare_label, data: @compare.map { |point| point[:y] } }] : plotted
    end

    def points_for(points)
      case @type
      when :scatter then points.map { |point| [point[:x], point[:y]] }
      when :bubble then points.map { |point| { x: point[:x], y: point[:y], z: point[:z] || 1 } }
      else points.map { |point| point[:y] }
      end
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

      {
        categories: categories,
        labels: {
          show: categories.any? && !sparkline?,
          style: { colors: config_color(:text), fontFamily: "inherit", fontSize: "12px" },
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
    end

    # Scatter and bubble plot real x values. Handing Apex a `categories` array
    # alongside numeric pair data makes it plot nothing at all, so the numeric
    # axis is built without one.
    def numeric_axis(axis)
      base = {
        labels: {
          show: true,
          style: { colors: config_color(:text), fontFamily: "inherit", fontSize: "12px" }
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

      magnitude = 10**Math.log10(raw).floor
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

      {
        # Stripe-style dashboards hang the scale on the right so the plot starts
        # flush with the card's left edge.
        opposite: @options[:axis] == :right,
        labels: {
          show: !sparkline?,
          style: { colors: config_color(:text), fontFamily: "inherit", fontSize: "12px" }
        },
        tickAmount: 5,
        axisBorder: { show: false },
        axisTicks: { show: false }
      }
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
        size: 0,
        strokeWidth: 2,
        strokeColors: surface_color,
        hover: { size: 6, sizeOffset: 0 }
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
        style: { fontFamily: "inherit", fontSize: "12px" }
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
        { curve: curve, width: 2, lineCap: "round" }
      when :bar, :column
        { show: true, width: 0, colors: ["transparent"] }
      when :bubble
        { show: false }
      else
        { curve: curve, width: 2, lineCap: "round" }
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
      case @type
      when :sparkline then "line"
      when :column, :bar then "bar"
      when :donut then "donut"
      when :polar_area then "polarArea"
      else @type.to_s
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
