# frozen_string_literal: true

module RailsuiCharts
  module ChartHelper
    # Forms whose placeholder should be a disc rather than a plotting area.
    CIRCULAR_TYPES = %i[pie donut polar_area radar].freeze

    def railsui_chart(data, type: :line, **options)
      # An empty dataset is a normal day one, not an error. Rendering axes
      # around nothing looks like a chart that failed rather than a chart with
      # nothing to show yet.
      return railsui_chart_empty(**empty_options(options)) if ApexOptionsBuilder.blank?(data)

      config = ApexOptionsBuilder.new(data, type: type, **options).build
      id = options[:id] || "rui-chart-#{SecureRandom.hex(4)}"

      table = options[:accessible] != false ? accessibility_table(config, id: id) : nil

      content_tag(:div,
                  id: id,
                  class: "railsui-chart",
                  data: { controller: "railsui-chart", "railsui-chart-options-value": config.to_json }) do
        table
      end
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
    # the thing a Turbo frame shows before it swaps in the real one. Pass the
    # `type:` it will become so the placeholder is the shape being waited on.
    def railsui_chart_skeleton(height: nil, type: :line, label: "Loading chart")
      classes = ["railsui-chart-skeleton"]
      classes << "railsui-chart-skeleton--circular" if CIRCULAR_TYPES.include?(type.to_sym)

      content_tag(:div,
                  class: "railsui-chart-state railsui-chart-state--loading",
                  style: state_height(height),
                  role: "status",
                  aria: { label: label, busy: true }) do
        content_tag(:span, "", class: classes.join(" "), aria: { hidden: true })
      end
    end

    private

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
    # hovering a mark.
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
      end

      rows = columns.first&.dig(:data)
      return if rows.blank?

      content_tag(:table, class: "sr-only", aria: { label: "Chart data" }) do
        safe_join([
          content_tag(:caption, "Data for chart #{id}"),
          content_tag(:thead) do
            content_tag(:tr) do
              safe_join(
                [content_tag(:th, "Category")] +
                  columns.map { |column| content_tag(:th, column[:name]) }
              )
            end
          end,
          content_tag(:tbody) do
            safe_join(
              rows.each_with_index.map do |_, index|
                content_tag(:tr) do
                  safe_join(
                    [content_tag(:td, categories[index] || index + 1)] +
                      columns.map { |column| content_tag(:td, cell_value(column[:data][index])) }
                  )
                end
              end
            )
          end
        ])
      end
    end

    def cell_value(value)
      case value
      when Array then value.join(", ")
      when Hash then value.values_at(:x, :y, :z).compact.join(", ")
      else value
      end
    end
  end
end
