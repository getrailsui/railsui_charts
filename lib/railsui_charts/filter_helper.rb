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
    #
    # The controls are deliberately bare — text and a chevron, with the pill
    # only appearing on hover. Filter chrome sits above the data all day, so it
    # earns its weight only while someone is reaching for it.
    #
    # An app that would rather use its own form styles passes them in. Doing so
    # drops the built-in chevron and switch, since those belong to this
    # treatment:
    #
    #   <%= railsui_chart_filters @filters, url: dashboard_path,
    #         select_class: "form-select w-auto", checkbox_class: "form-input-checkbox" %>
    def railsui_chart_filters(filters, url: nil, frame: nil, select_class: nil, checkbox_class: nil)
      bare_selects = select_class.nil?
      switch = checkbox_class.nil?
      select_class ||= "railsui-chart-filters__select"
      checkbox_class ||= "railsui-chart-filters__checkbox"

      form_tag(url, method: :get, class: "railsui-chart-filters", data: filter_form_data(frame)) do
        safe_join([
          filter_field("Date range",
                       select_tag(:range, options_for_select(filters.presets.map { |preset| [preset.label, preset.key] }, filters.preset.key), **filter_select_options(select_class)),
                       chevron: bare_selects),
          filter_field("Interval",
                       select_tag(:interval, options_for_select(filters.intervals, filters.interval.to_s), **filter_select_options(select_class)),
                       chevron: bare_selects),
          filter_compare(filters, checkbox_class, switch: switch),
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

    def filter_field(label, control, chevron:)
      content_tag(:div, class: "railsui-chart-filters__field") do
        safe_join([
          content_tag(:span, label, class: "railsui-chart-filters__label"),
          # The chevron rides a wrapper rather than a background image on the
          # select, so it inherits currentColor and follows the theme.
          chevron ? content_tag(:span, control, class: "railsui-chart-filters__control") : control
        ])
      end
    end

    def filter_select_options(select_class)
      {
        class: select_class,
        data: { action: "change->railsui-chart-filters#submit" }
      }
    end

    def filter_compare(filters, checkbox_class, switch:)
      classes = ["railsui-chart-filters__compare"]
      classes << "railsui-chart-filters__compare--switch" if switch

      content_tag(:label, class: classes.join(" ")) do
        safe_join([
          # Paired hidden field so unchecking sends an explicit value rather
          # than dropping the param and falling back to the default.
          hidden_field_tag(:compare, "0", id: nil),
          check_box_tag(:compare, "1", filters.compare?,
                        class: switch ? "railsui-chart-filters__switch" : checkbox_class,
                        data: { action: "change->railsui-chart-filters#submit" }),
          # Adjacent sibling of the input, which is what drives the checked and
          # focus states.
          switch ? content_tag(:span, "", class: "railsui-chart-filters__track", aria: { hidden: true }) : nil,
          content_tag(:span, "Compare to previous period")
        ].compact)
      end
    end
  end
end
