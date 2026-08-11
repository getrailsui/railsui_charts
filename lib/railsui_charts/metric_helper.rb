# frozen_string_literal: true

module RailsuiCharts
  module MetricHelper
    def railsui_metric(label:, value:, change: nil, comparison: nil, history: nil, format: :number, **options)
      change ||= comparison
      trend = trend_direction(change)
      sparkline = metric_sparkline(history, options)

      content_tag(:div, class: "railsui-metric") do
        safe_join([
          content_tag(:p, label, class: "railsui-metric-label"),
          content_tag(:div, class: "railsui-metric-value-row") do
            safe_join([
              format_metric_value(value, format),
              change ? metric_change_badge(change, trend) : nil
            ].compact)
          end,
          sparkline
        ].compact)
      end
    end

    private

    def format_metric_value(value, format)
      formatted = case format
                  when :currency
                    number_to_currency(value)
                  when :percentage
                    number_to_percentage(value, precision: 1)
                  when :human
                    number_to_human(value)
                  else
                    number_with_delimiter(value)
                  end

      content_tag(:span, formatted, class: "railsui-metric-value")
    end

    def metric_change_badge(change, trend)
      return if change.nil?

      sign = change.positive? ? "+" : ""
      classes = ["railsui-metric-change", "railsui-metric-change--#{trend}"]
      content_tag(:span, "#{sign}#{change}%", class: classes.join(" "))
    end

    def trend_direction(change)
      return "neutral" if change.nil? || change.zero?
      change.positive? ? "positive" : "negative"
    end

    def metric_sparkline(history, options)
      return if history.blank?

      railsui_chart(history, type: :sparkline, height: 40, accessible: false, **options.except(:id))
    end
  end
end
