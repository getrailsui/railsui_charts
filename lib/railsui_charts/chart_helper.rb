# frozen_string_literal: true

module RailsuiCharts
  module ChartHelper
    def railsui_chart(data, type: :line, **options)
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

    private

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
