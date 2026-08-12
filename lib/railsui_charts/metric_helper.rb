# frozen_string_literal: true

module RailsuiCharts
  module MetricHelper
    # A compact label / value / delta stack with an optional sparkline.
    def railsui_metric(label:, value:, change: nil, comparison: nil, history: nil, format: :number, **options)
      change ||= comparison
      sparkline = metric_sparkline(history, options)

      content_tag(:div, class: "railsui-metric") do
        safe_join([
          content_tag(:p, label, class: "railsui-metric-label"),
          content_tag(:div, class: "railsui-metric-value-row") do
            safe_join([
              content_tag(:span, format_metric_value(value, format), class: "railsui-metric-value"),
              change ? metric_delta(change) : nil
            ].compact)
          end,
          sparkline
        ].compact)
      end
    end

    # The full dashboard card: label, value, delta, previous-period line, a
    # comparison chart, and a footer. This is the piece a Rails app actually
    # drops into a dashboard — the chart alone is rarely the whole job.
    def railsui_metric_card(label:, value:, previous: nil, change: nil, history: nil, compare: nil,
                            format: :number, updated_at: nil, details_path: nil,
                            details_label: "More details", positive_is_good: true,
                            chart_height: 180, **options)
      change ||= percentage_change(value, previous)

      content_tag(:div, class: "railsui-metric-card") do
        safe_join([
          metric_card_head(label, value, change, previous, format, positive_is_good),
          metric_card_chart(history, compare, format, chart_height, options.merge(label: options[:label] || label)),
          metric_card_footer(updated_at, details_path, details_label)
        ].compact)
      end
    end

    private

    def metric_card_head(label, value, change, previous, format, positive_is_good)
      content_tag(:div, class: "railsui-metric-card__head") do
        safe_join([
          content_tag(:p, label, class: "railsui-metric-card__label"),
          content_tag(:div, class: "railsui-metric-card__value-row") do
            safe_join([
              content_tag(:span, format_metric_value(value, format), class: "railsui-metric-card__value"),
              change ? metric_delta(change, positive_is_good: positive_is_good) : nil
            ].compact)
          end,
          previous ? content_tag(:p, "#{format_metric_value(previous, format)} previous period", class: "railsui-metric-card__previous") : nil
        ].compact)
      end
    end

    def metric_card_chart(history, compare, format, height, options)
      # No early return on blank history: railsui_chart renders its empty panel
      # at the same height, so a card with nothing to plot keeps its shape
      # instead of collapsing and shuffling the grid around it.
      content_tag(:div, class: "railsui-metric-card__chart") do
        safe_join([
          railsui_chart(
            history,
            type: :line,
            compare: compare,
            # The value above is already spelled out in full, so the axis takes
            # the compact form: $19K rather than $19,000.00.
            format: format == :currency ? :short_currency : format,
            height: height,
            # The end labels are rendered below as plain text instead. Apex
            # centres a label on its data point and clips at the canvas edge, so
            # an edge label either loses its first characters or has to be
            # bought with padding that eats into the plot.
            xaxis: { labels: { show: false } },
            grid: { padding: { left: 0, right: 4, top: 0, bottom: 0 } },
            # Scale on the right, so the plot starts flush with the card edge.
            axis: :right,
            # The "previous period" line above already names the comparison, so a
            # legend box would only restate it and eat the card's height.
            legend: { show: false },
            **options
          ),
          metric_card_axis(history)
        ].compact)
      end
    end

    # First and last labels, flush to the card edges. Nothing to clip, and the
    # plot keeps its full width.
    def metric_card_axis(history)
      labels = Array(history).filter_map { |point| point[:x] || point["x"] if point.is_a?(Hash) }
      return if labels.length < 2

      content_tag(:div, class: "railsui-metric-card__axis") do
        safe_join([content_tag(:span, labels.first), content_tag(:span, labels.last)])
      end
    end

    def metric_card_footer(updated_at, details_path, details_label)
      return if updated_at.blank? && details_path.blank?

      content_tag(:div, class: "railsui-metric-card__footer") do
        safe_join([
          content_tag(:span, updated_at, class: "railsui-metric-card__updated"),
          details_path.present? ? link_to(details_label, details_path, class: "railsui-metric-card__details") : nil
        ].compact)
      end
    end

    def format_metric_value(value, format)
      case format
      when :currency, :short_currency
        number_to_currency(value)
      when :percentage
        number_to_percentage(value, precision: 1)
      when :human
        number_to_human(value, units: { thousand: "K", million: "M", billion: "B" }, format: "%n%u", precision: 3)
      else
        number_with_delimiter(value)
      end
    end

    # Plain coloured text, not a pill. A filled badge competes with the value
    # it is annotating.
    def metric_delta(change, positive_is_good: true)
      return if change.nil?

      trend = trend_direction(change, positive_is_good: positive_is_good)
      sign = change.to_f.positive? ? "+" : ""

      content_tag(:span, "#{sign}#{format_change(change)}%", class: "railsui-metric-delta railsui-metric-delta--#{trend}")
    end

    def format_change(change)
      rounded = change.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i : rounded
    end

    # Direction and goodness are separate: a falling churn rate is a win, so the
    # colour follows meaning rather than the sign.
    def trend_direction(change, positive_is_good: true)
      return "neutral" if change.nil? || change.to_f.zero?

      change.to_f.positive? == positive_is_good ? "positive" : "negative"
    end

    def percentage_change(value, previous)
      return if value.nil? || previous.nil? || previous.to_f.zero?

      ((value.to_f - previous.to_f) / previous.to_f * 100).round(2)
    end

    def metric_sparkline(history, options)
      return if history.blank?

      railsui_chart(history, type: :sparkline, height: 40, accessible: false, **options.except(:id))
    end
  end
end
