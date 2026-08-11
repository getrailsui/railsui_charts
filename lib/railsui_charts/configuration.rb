# frozen_string_literal: true

module RailsuiCharts
  class Configuration
    attr_accessor :default_height, :default_currency, :colors, :theme_css_prefix

    def initialize
      @default_height = 250
      @default_currency = "$"
      @theme_css_prefix = "--rui-chart"
      @colors = {
        primary: "var(--rui-chart-primary, #4f46e5)",
        secondary: "var(--rui-chart-secondary, #0ea5e9)",
        accent: "var(--rui-chart-accent, #10b981)",
        muted: "var(--rui-chart-muted, #94a3b8)",
        grid: "var(--rui-chart-grid, rgba(148, 163, 184, 0.2))",
        text: "var(--rui-chart-text, #64748b)"
      }
    end
  end
end
