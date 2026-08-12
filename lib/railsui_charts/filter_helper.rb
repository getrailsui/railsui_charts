# frozen_string_literal: true

module RailsuiCharts
  module FilterHelper
    # Renders the single filter row that scopes every chart below it.
    #
    #   <%= railsui_chart_filters @filters, url: dashboard_path %>
    #
    # Submits as a plain GET form, so it works without JavaScript and each
    # slice gets a shareable URL. With Turbo, the controller submits on change
    # and only the frame re-renders.
    def railsui_chart_filters(filters, url: nil, frame: nil)
      form_tag(url, method: :get, class: "railsui-chart-filters", data: filter_form_data(frame)) do
        safe_join([
          filter_field("Date range", select_tag(:range, options_for_select(filters.presets.map { |preset| [preset.label, preset.key] }, filters.preset.key), **filter_select_options)),
          filter_field("Interval", select_tag(:interval, options_for_select(filters.intervals, filters.interval.to_s), **filter_select_options)),
          filter_compare(filters),
          # Without Turbo or Stimulus the selects still need a way to apply.
          content_tag(:noscript, submit_tag("Apply", class: "railsui-chart-filters__apply", data: { disable_with: nil }))
        ])
      end
    end

    private

    def filter_form_data(frame)
      data = { controller: "railsui-chart-filters" }
      data[:turbo_frame] = frame if frame.present?
      data
    end

    def filter_field(label, control)
      content_tag(:div, class: "railsui-chart-filters__field") do
        safe_join([
          content_tag(:span, label, class: "railsui-chart-filters__label"),
          control
        ])
      end
    end

    def filter_select_options
      {
        class: "railsui-chart-filters__select",
        data: { action: "change->railsui-chart-filters#submit" }
      }
    end

    def filter_compare(filters)
      content_tag(:label, class: "railsui-chart-filters__compare") do
        safe_join([
          # Paired hidden field so unchecking sends an explicit value rather
          # than dropping the param and falling back to the default.
          hidden_field_tag(:compare, "0", id: nil),
          check_box_tag(:compare, "1", filters.compare?,
                        class: "railsui-chart-filters__checkbox",
                        data: { action: "change->railsui-chart-filters#submit" }),
          content_tag(:span, "Compare to previous period")
        ])
      end
    end
  end
end
