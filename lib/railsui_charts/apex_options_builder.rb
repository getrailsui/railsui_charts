# frozen_string_literal: true

module RailsuiCharts
  class ApexOptionsBuilder
    SUPPORTED_TYPES = %i[line area bar column sparkline pie donut scatter bubble radar polar_area].freeze

    def initialize(data, type: :line, **options)
      @data = normalize_data(data)
      @type = validate_type(type)
      @options = options
    end

    def build
      deep_merge(base_options, chart_specific_options, user_options)
    end

    private

    def validate_type(type)
      type = type.to_sym
      raise ArgumentError, "Unsupported chart type: #{type}. Supported: #{SUPPORTED_TYPES.join(', ')}" unless SUPPORTED_TYPES.include?(type)
      type
    end

    def normalize_data(data)
      data = data.to_a if data.respond_to?(:to_a) && !data.is_a?(Array)

      data.map do |point|
        case point
        when Hash
          { x: point[:x] || point["x"], y: point[:y] || point["y"], z: point[:z] || point["z"] }
        when Array
          { x: point[0], y: point[1], z: point[2] }
        else
          { x: nil, y: point, z: nil }
        end
      end
    end

    def categories
      @data.map { |d| d[:x] }.compact
    end

    def series_values
      @data.map { |d| d[:y] }
    end

    def scatter_series
      @data.map { |d| [d[:x], d[:y]] }
    end

    def bubble_series
      @data.map { |d| { x: d[:x], y: d[:y], z: d[:z] || 1 } }
    end

    def base_options
      {
        chart: {
          type: apex_chart_type,
          height: @options[:height] || RailsuiCharts.config.default_height,
          toolbar: { show: false },
          animations: { enabled: true },
          fontFamily: "inherit"
        },
        series: series_for_type,
        xaxis: xaxis_options,
        yaxis: yaxis_options,
        grid: grid_options,
        colors: colors_for_type,
        dataLabels: { enabled: false },
        stroke: stroke_options,
        fill: fill_options,
        markers: { size: sparkline? ? 0 : 4 },
        tooltip: {
          theme: "dark",
          x: { show: !circular? && categories.any? },
          style: { fontFamily: "inherit" }
        },
        theme: {
          mode: "light"
        }
      }
    end

    def chart_specific_options
      case @type
      when :sparkline
        {
          chart: { sparkline: { enabled: true } },
          grid: { show: false },
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } }
        }
      when :bar
        {
          plotOptions: { bar: { horizontal: true, borderRadius: 4 } }
        }
      when :column
        {
          plotOptions: { bar: { horizontal: false, borderRadius: 4 } }
        }
      when :pie, :donut
        {
          labels: categories.any? ? categories : @data.map.with_index { |_, i| "Item #{i + 1}" },
          plotOptions: circular_plot_options,
          dataLabels: { enabled: false },
          legend: circular_legend,
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } },
          grid: { show: false }
        }
      when :scatter
        {
          markers: { size: 6, strokeWidth: 0, hover: { size: 8 } },
          xaxis: { type: "numeric", labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } },
          yaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } }
        }
      when :bubble
        {
          plotOptions: { bubble: { zScaling: true, minBubbleRadius: 6, maxBubbleRadius: 28 } },
          markers: { strokeWidth: 0 },
          fill: { opacity: 1 },
          xaxis: { type: "numeric", labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } },
          yaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } }
        }
      when :radar
        {
          markers: { size: 5, strokeWidth: 0, hover: { size: 7 } },
          stroke: { curve: "straight", width: 2, colors: [config_color(:primary)] },
          fill: { opacity: 0.5, colors: [config_color(:primary)] },
          xaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } },
          yaxis: { showAlways: false, labels: { show: false } },
          grid: { show: true, borderColor: config_color(:grid), strokeDashArray: 4 }
        }
      when :polar_area
        {
          labels: categories.any? ? categories : @data.map.with_index { |_, i| "Item #{i + 1}" },
          plotOptions: { polarArea: { rings: { strokeWidth: 0 }, spokes: { connectorColors: "transparent" } } },
          dataLabels: { enabled: false },
          legend: circular_legend,
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } },
          grid: { show: false }
        }
      else
        {}
      end
    end

    def circular_plot_options
      case @type
      when :donut
        { pie: { donut: { size: "55%", labels: { show: false } } } }
      when :pie
        { pie: { offsetX: 0, offsetY: 0 } }
      else
        {}
      end
    end

    def circular_legend
      {
        position: "bottom",
        fontFamily: "inherit",
        fontSize: "12px",
        itemMargin: { horizontal: 10, vertical: 4 },
        labels: { colors: config_color(:text) },
        markers: { radius: 3 }
      }
    end

    def series_for_type
      case @type
      when :pie, :donut, :polar_area
        series_values
      when :scatter
        [{ name: @options[:label] || "Value", data: scatter_series }]
      when :bubble
        [{ name: @options[:label] || "Value", data: bubble_series }]
      when :radar
        [{ name: @options[:label] || "Value", data: series_values }]
      else
        [{ name: @options[:label] || "Value", data: series_values }]
      end
    end

    def xaxis_options
      return { labels: { show: false } } if circular?

      {
        categories: categories,
        labels: {
          show: categories.any? && !sparkline?,
          style: { colors: config_color(:text), fontFamily: "inherit" }
        },
        axisBorder: { show: false },
        axisTicks: { show: false },
        crosshairs: { show: false },
        type: numeric_xaxis? ? "numeric" : "category"
      }
    end

    def yaxis_options
      return { labels: { show: false } } if circular?

      {
        labels: {
          show: !sparkline?,
          style: { colors: config_color(:text), fontFamily: "inherit" }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      }
    end

    def grid_options
      return { show: false } if circular? || sparkline?

      {
        show: true,
        borderColor: config_color(:grid),
        strokeDashArray: 4,
        xaxis: { lines: { show: false } },
        yaxis: { lines: { show: true } }
      }
    end

    def colors_for_type
      return [solid_color(:primary), solid_color(:secondary), solid_color(:accent), solid_color(:muted)] if circular? || radar? || bubble?
      [config_color(:primary)]
    end

    def radar?
      @type == :radar
    end

    def bubble?
      @type == :bubble
    end

    def stroke_options
      case @type
      when :sparkline
        { curve: "smooth", width: 2 }
      when :bar, :column
        { show: true, width: 0, colors: ["transparent"] }
      when :bubble
        { show: false }
      else
        { curve: "smooth", width: 3 }
      end
    end

    def fill_options
      case @type
      when :area
        {
          type: "gradient",
          gradient: {
            shadeIntensity: 1,
            opacityFrom: 0.4,
            opacityTo: 0.05,
            stops: [0, 100]
          }
        }
      when :bar, :column, :pie, :donut, :polar_area
        { opacity: 1 }
      else
        { opacity: 0 }
      end
    end

    def deep_merge(*hashes)
      hashes.each_with_object({}) do |hash, result|
        hash.each do |key, value|
          result[key] = if value.is_a?(Hash) && result[key].is_a?(Hash)
                          deep_merge(result[key], value)
                        else
                          value
                        end
        end
      end
    end

    def user_options
      opts = @options.except(:type, :height, :label)
      opts[:colors] = Array(opts[:colors]).map { |c| config_color(c) || c } if opts.key?(:colors)
      opts[:currency] ||= RailsuiCharts.config.default_currency if %w[currency short_currency].include?(opts[:format].to_s)
      opts
    end

    def apex_chart_type
      case @type
      when :sparkline then "line"
      when :column, :bar then "bar"
      when :donut then "donut"
      when :polar_area then "polarArea"
      else @type.to_s
      end
    end

    def sparkline?
      @type == :sparkline
    end

    def circular?
      %i[pie donut polar_area].include?(@type)
    end

    def numeric_xaxis?
      %i[scatter bubble].include?(@type)
    end

    def config_color(key)
      RailsuiCharts.config.colors[key]
    end

    def solid_color(key)
      value = config_color(key).to_s
      if value.start_with?("var(")
        fallback = value.match(/var\([^,]+,\s*([^)]+)\)/)&.captures&.first
        fallback || value
      else
        value
      end
    end
  end
end
