# frozen_string_literal: true

module RailsuiCharts
  class ApexOptionsBuilder
    SUPPORTED_TYPES = %i[line area bar sparkline].freeze

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

    def base_options
      {
        chart: {
          type: apex_chart_type,
          height: @options[:height] || RailsuiCharts.config.default_height,
          toolbar: { show: false },
          animations: { enabled: true },
          fontFamily: "inherit"
        },
        series: [{
          name: @options[:label] || "Value",
          data: series_values
        }],
        xaxis: {
          categories: categories,
          labels: {
            show: categories.any?,
            style: { colors: config_color(:text), fontFamily: "inherit" }
          },
          axisBorder: { show: false },
          axisTicks: { show: false },
          crosshairs: { show: false }
        },
        yaxis: {
          labels: {
            show: !sparkline?,
            style: { colors: config_color(:text), fontFamily: "inherit" }
          },
          axisBorder: { show: false },
          axisTicks: { show: false }
        },
        grid: {
          show: !sparkline?,
          borderColor: config_color(:grid),
          strokeDashArray: 4,
          xaxis: { lines: { show: false } },
          yaxis: { lines: { show: true } }
        },
        colors: [config_color(:primary)],
        dataLabels: { enabled: false },
        stroke: {
          curve: "smooth",
          width: sparkline? ? 2 : 3
        },
        fill: fill_options,
        markers: { size: sparkline? ? 0 : 4 },
        tooltip: {
          theme: "dark",
          x: { show: categories.any? },
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
      else
        {}
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
      else @type.to_s
      end
    end

    def sparkline?
      @type == :sparkline
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
      else
        { opacity: 0 }
      end
    end

    def config_color(key)
      RailsuiCharts.config.colors[key]
    end
  end
end
