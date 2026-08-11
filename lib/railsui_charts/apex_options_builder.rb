# frozen_string_literal: true

module RailsuiCharts
  class ApexOptionsBuilder
    SUPPORTED_TYPES = %i[line area bar column sparkline pie donut scatter].freeze

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
          { x: point[:x] || point["x"], y: point[:y] || point["y"] }
        when Array
          { x: point[0], y: point[1] }
        else
          { x: nil, y: point }
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
          dataLabels: { enabled: true },
          xaxis: { labels: { show: false } },
          yaxis: { labels: { show: false } },
          grid: { show: false }
        }
      when :scatter
        {
          xaxis: { type: "numeric", labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } },
          yaxis: { labels: { show: true, style: { colors: config_color(:text), fontFamily: "inherit" } } }
        }
      else
        {}
      end
    end

    def circular_plot_options
      case @type
      when :donut
        { pie: { donut: { size: "65%" } } }
      else
        {}
      end
    end

    def series_for_type
      case @type
      when :pie, :donut
        series_values
      when :scatter
        [{ name: @options[:label] || "Value", data: scatter_series }]
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
        type: @type == :scatter ? "numeric" : "category"
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
      return [config_color(:primary), config_color(:secondary), config_color(:accent), config_color(:muted)] if circular?
      [config_color(:primary)]
    end

    def stroke_options
      case @type
      when :sparkline
        { curve: "smooth", width: 2 }
      when :bar, :column
        { show: true, width: 0, colors: ["transparent"] }
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
      when :bar, :column
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
      opts
    end

    def apex_chart_type
      case @type
      when :sparkline then "line"
      when :column, :bar then "bar"
      when :donut then "donut"
      else @type.to_s
      end
    end

    def sparkline?
      @type == :sparkline
    end

    def circular?
      %i[pie donut].include?(@type)
    end

    def config_color(key)
      RailsuiCharts.config.colors[key]
    end
  end
end
