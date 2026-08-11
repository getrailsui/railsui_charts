# frozen_string_literal: true

module RailsuiCharts
  module ChartHelper
    def railsui_chart(data, type: :line, **options)
      builder = ApexOptionsBuilder.new(data, type: type, **options)
      config = builder.build
      id = options[:id] || "rui-chart-#{SecureRandom.hex(4)}"

      table = options[:accessible] != false ? accessibility_table(config[:series], id: id) : nil
      options_value = config.to_json

      content_tag(:div, class: "railsui-chart", data: { controller: "railsui-chart", "railsui-chart-options-value": options_value }) do
        table
      end
    end

    private

    def accessibility_table(series, id:)
      return if series.blank?

      data = series.first[:data]
      categories = series.first[:categories] || []

      content_tag(:table, class: "sr-only", aria: { label: "Chart data" }) do
        safe_join([
          content_tag(:caption, "Data for chart #{id}"),
          content_tag(:thead) do
            content_tag(:tr) do
              safe_join([
                content_tag(:th, "Index"),
                content_tag(:th, "Value")
              ])
            end
          end,
          content_tag(:tbody) do
            safe_join(
              data.each_with_index.map do |value, index|
                content_tag(:tr) do
                  safe_join([
                    content_tag(:td, categories[index] || index),
                    content_tag(:td, value)
                  ])
                end
              end
            )
          end
        ])
      end
    end
  end
end
