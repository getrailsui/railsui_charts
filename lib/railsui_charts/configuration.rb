# frozen_string_literal: true

module RailsuiCharts
  class Configuration
    attr_accessor :default_height, :default_currency, :colors, :series_colors, :theme_css_prefix

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
  end
end
