# frozen_string_literal: true

module RailsuiCharts
  module ChartHelper
    # Forms whose placeholder should be a disc rather than a plotting area.
    CIRCULAR_TYPES = %i[pie donut polar_area radar].freeze

    def railsui_chart(data, type: :line, **options)
      # A chart whose series are not the numbers a reader wants can say so.
      # Deleted rather than read, so it never reaches the builder and never
      # gets serialised into the Stimulus value alongside the real config.
      explicit_table = options.delete(:accessible_table)

      # An empty dataset is a normal day one, not an error. Rendering axes
      # around nothing looks like a chart that failed rather than a chart with
      # nothing to show yet.
      return railsui_chart_empty(**empty_options(options)) if ApexOptionsBuilder.blank?(data)

      config = ApexOptionsBuilder.new(data, type: type, **options).build
      id = options[:id] || "rui-chart-#{SecureRandom.hex(4)}"

      table =
        if options[:accessible] == false
          nil
        elsif explicit_table.present?
          explicit_accessibility_table(explicit_table, id: id)
        else
          accessibility_table(config, id: id)
        end

      content_tag(:div,
                  id: id,
                  class: "railsui-chart",
                  # Charts draw when they scroll into view, so the space has to
                  # be held from the start. Without it the page is short on
                  # load and grows under the reader as they scroll.
                  style: reserved_height(config),
                  data: { controller: "railsui-chart", "railsui-chart-options-value": config.to_json }) do
        table
      end
    end

    # One small chart per series, sharing a y-scale.
    #
    # This is the honest answer when there are more categories than a single
    # chart can hold. Eight lines on one axis is a plate of spaghetti, and a
    # ninth colour is not distinguishable from the others anyway — facets scale
    # where colour does not.
    #
    #   <%= railsui_small_multiples @plans, type: :area, columns: 3 %>
    def railsui_small_multiples(series, type: :line, height: 120, columns: 3, **options)
      return railsui_chart_empty(**empty_options(options)) if ApexOptionsBuilder.blank?(series)

      entries = Array(series)
      shared = shared_scale(entries)

      content_tag(:div, class: "railsui-small-multiples", style: "--rui-small-multiple-columns: #{columns.to_i}") do
        safe_join(entries.each_with_index.map do |entry, index|
          content_tag(:div, class: "railsui-small-multiple") do
            safe_join([
              content_tag(:p, entry[:name] || entry["name"] || "Series #{index + 1}", class: "railsui-small-multiple__title"),
              # Every facet takes the same colour. The title carries identity
              # here, so spending a hue on it would say nothing extra.
              railsui_chart(entry[:data] || entry["data"], type: type, height: height,
                                                           yaxis: shared.merge(tickAmount: 3), **options)
            ])
          end
        end)
      end
    end

    # Facets only compare if they share a scale. Left to themselves each one
    # would fit its own data and a small series would look like a large one.
    def shared_scale(entries)
      values = entries.flat_map { |entry| Array(entry[:data] || entry["data"]).map { |point| ApexOptionsBuilder.value_of(point) } }.compact
      return {} if values.empty?

      min, max = values.minmax
      return {} if min == max

      { min: min, max: max }
    end

    # Holds the chart's footprint so a card keeps its shape whether or not the
    # query came back with anything.
    def railsui_chart_empty(title: nil, description: nil, height: nil)
      chart_state(:empty, title: title || "No data", description: description, height: height)
    end

    def railsui_chart_error(title: nil, description: nil, height: nil)
      chart_state(:error, title: title || "Couldn't load this chart", description: description, height: height)
    end

    # Server-rendered placeholder for a chart whose data has not arrived yet —
    # the thing a Turbo frame shows before it swaps in the real one. It keeps
    # the chart footprint and avoids drawing fake chart geometry before data
    # exists.
    def railsui_chart_skeleton(height: nil, type: :line, label: "Loading chart", align: :left)
      alignment = skeleton_alignment(align)

      content_tag(:div,
                  class: "railsui-chart-state railsui-chart-state--loading railsui-chart-state--loading-#{alignment}",
                  style: state_height(height),
                  role: "status",
                  aria: { label: label, busy: true }) do
        content_tag(:div, class: "railsui-chart-skeleton", aria: { hidden: true }) do
          safe_join([
            content_tag(:span, "", class: "railsui-skeleton-bar railsui-skeleton-bar--label"),
            content_tag(:span, "", class: "railsui-skeleton-bar railsui-skeleton-bar--value"),
            content_tag(:span, "", class: "railsui-skeleton-bar railsui-skeleton-bar--meta"),
            content_tag(:span, "", class: "railsui-chart-skeleton__plot"),
            content_tag(:span, "", class: "railsui-skeleton-bar railsui-skeleton-bar--footer")
          ])
        end
      end
    end

    private

    def skeleton_alignment(align)
      alignment = align.to_sym
      return alignment if %i[left center right].include?(alignment)

      raise ArgumentError, "Unsupported skeleton alignment: #{align}. Supported: left, center, right"
    end

    def chart_state(kind, title:, description:, height:)
      content_tag(:div,
                  class: "railsui-chart-state railsui-chart-state--#{kind}",
                  style: state_height(height),
                  role: "status") do
        content_tag(:div, class: "railsui-chart-state__body") do
          safe_join([
            content_tag(:p, title, class: "railsui-chart-state__title"),
            description.present? ? content_tag(:p, description, class: "railsui-chart-state__description") : nil
          ].compact)
        end
      end
    end

    def reserved_height(config)
      height = config.dig(:chart, :height)
      return if height.blank?

      "min-height: #{height.to_i}px"
    end

    def state_height(height)
      height ||= RailsuiCharts.config.default_height
      "min-height: #{height.to_i}px"
    end

    # `empty:` takes a string for the headline, or a hash to say more.
    def empty_options(options)
      given = options[:empty]
      base = { height: options[:height] }

      case given
      when String then base.merge(title: given)
      when Hash then base.merge(given.symbolize_keys)
      else base
      end
    end

    # Every chart ships a visually hidden table so no value is reachable only by
    # hovering a mark. The hiding is the gem's own — `sr-only` rides along for
    # apps that already style it, but a host utility cannot be relied on to
    # exist, and Tailwind's does not actually hide a table. See
    # railsui-chart-data-table in the stylesheet.
    #
    # The table a caller supplied, rather than one derived from the series.
    #
    # This is the accessible half of an extension point: a downstream helper
    # that stacks scaffolding series to get a shape Apex can draw — a waterfall
    # holding bars at a running total, say — can still tell a screen reader
    # what the chart means. The CSV export is built from this table too, so it
    # gets the same correction for free.
    def explicit_accessibility_table(table, id:)
      headers = Array(table[:headers] || table["headers"])
      rows = Array(table[:rows] || table["rows"])
      return if rows.blank?

      content_tag(:table, class: "railsui-chart-data-table sr-only", aria: { label: "Chart data" }) do
        safe_join([
          content_tag(:caption, "Data for chart #{id}"),
          content_tag(:thead) do
            content_tag(:tr) { safe_join(headers.map { |header| content_tag(:th, header) }) }
          end,
          content_tag(:tbody) do
            safe_join(rows.map do |row|
              content_tag(:tr) do
                safe_join(Array(row).map { |cell| content_tag(:td, cell_value(cell)) })
              end
            end)
          end
        ])
      end
    end

    def accessibility_table(config, id:)
      series = config[:series]
      return if series.blank?

      if series.is_a?(Array) && series.first.is_a?(Numeric)
        # Pie / donut / polar area: a flat array of values with separate labels.
        columns = [{ name: "Value", data: series }]
        categories = config[:labels] || []
      else
        columns = Array(series).map { |s| { name: s[:name] || "Value", data: s[:data] } }
        categories = config.dig(:xaxis, :categories) || []

        if categories.blank?
          point_categories = accessibility_point_categories(columns)
          if point_categories.present?
            categories = point_categories
            columns = columns.map do |column|
              column.merge(data: accessibility_align_points(column[:data], categories))
            end
          end
        end
      end
      comparison_categories = config[:compare_categories] || []

      rows = columns.first&.dig(:data)
      return if rows.blank?

      content_tag(:table, class: "railsui-chart-data-table sr-only", aria: { label: "Chart data" }) do
        safe_join([
          content_tag(:caption, "Data for chart #{id}"),
          content_tag(:thead) do
            content_tag(:tr) do
              safe_join(
                accessibility_category_headers(comparison_categories) +
                  columns.map { |column| content_tag(:th, column[:name]) }
              )
            end
          end,
          content_tag(:tbody) do
            safe_join(
              rows.each_with_index.map do |_, index|
                content_tag(:tr) do
                  safe_join(
                    accessibility_category_cells(categories, comparison_categories, index) +
                      columns.map { |column| content_tag(:td, cell_value(column[:data][index])) }
                  )
                end
              end
            )
          end
        ])
      end
    end

    def accessibility_category_headers(comparison_categories)
      headers = [content_tag(:th, "Category")]
      headers << content_tag(:th, "Comparison category") if comparison_categories.present?
      headers
    end

    def accessibility_point_categories(columns)
      columns.flat_map do |column|
        Array(column[:data]).filter_map { |value| value[:x] if value.is_a?(Hash) && value.key?(:x) }
      end.uniq
    end

    def accessibility_align_points(data, categories)
      points = Array(data).each_with_object({}) do |value, indexed|
        indexed[value[:x]] = value if value.is_a?(Hash) && value.key?(:x)
      end

      categories.map { |category| points[category] }
    end

    def accessibility_category_cells(categories, comparison_categories, index)
      cells = [content_tag(:td, categories[index] || index + 1)]
      cells << content_tag(:td, comparison_categories[index] || index + 1) if comparison_categories.present?
      cells
    end

    def cell_value(value)
      case value
      when Array then value.join(", ")
      when Hash
        # A bubble carries three numbers that all mean something here. Anything
        # else keeps its label in the category column already, so repeating it
        # beside the value just reads as "A, 6" to a screen reader.
        return value.values_at(:x, :y, :z).compact.join(", ") if value.key?(:z)

        cell_value(value[:y])
      else value
      end
    end
  end
end
