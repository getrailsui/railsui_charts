# frozen_string_literal: true

module RailsuiCharts
  class Configuration
    attr_accessor :default_height, :default_currency, :colors, :series_colors, :theme_css_prefix, :extra_types
    attr_accessor :labelled_point_types

    # Categorical hues carry identity, so the order is the colourblind-safety
    # mechanism rather than a style choice — it was picked by validating every
    # ordering of these hues and keeping one that clears the lightness band,
    # chroma floor, CVD separation, normal-vision floor, and 3:1 contrast in
    # both light and dark. Reorder it and those guarantees go with it.
    #
    # Forms where any two marks can sit side by side (pie, donut, polar area,
    # scatter, bubble) hold to a stricter all-pairs test, which these hues clear
    # for the first four slots. Past four, fold the tail into "Other".
    SERIES_COUNT = 8

    SERIES_FALLBACKS = %w[
      #6366f1 #ea580c #db2777 #c026d3
      #65a30d #0284c7 #dc2626 #0d9488
    ].freeze

    def initialize
      @default_height = 250
      @default_currency = "$"
      # Chart types registered by an extension, such as Rails UI Charts Pro.
      @extra_types = []
      @labelled_point_types = []
      @theme_css_prefix = "--rui-chart"
      @series_colors = (1..SERIES_COUNT).map { |i| "var(--rui-chart-series-#{i}, #{SERIES_FALLBACKS[i - 1]})" }
      @colors = {
        primary: "var(--rui-chart-primary, #4f46e5)",
        secondary: "var(--rui-chart-secondary, #0ea5e9)",
        accent: "var(--rui-chart-accent, #10b981)",
        muted: "var(--rui-chart-muted, #94a3b8)",
        grid: "var(--rui-chart-grid, rgba(148, 163, 184, 0.2))",
        text: "var(--rui-chart-text, #64748b)",
        # The card colour behind a chart. Touching marks separate with a gap in
        # this colour rather than a stroke drawn around them.
        surface: "var(--rui-chart-surface, #ffffff)"
      }
    end
    # Register a chart type this gem does not ship, so it passes validation and
    # is drawn through the same options builder as everything else rather than
    # around it.
    #
    #   RailsuiCharts.config.register_type :treemap, points: :labelled
    #
    # `points: :labelled` keeps each point as {x:, y:}. Most types put the label
    # on the axis and send bare values, but a treemap draws its labels inside
    # the rectangles, so they have to stay in the data.
    def register_type(type, points: :values)
      type = type.to_sym

      @extra_types |= [type]
      @labelled_point_types |= [type] if points == :labelled

      type
    end

  end
end
