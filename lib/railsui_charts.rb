# frozen_string_literal: true

require "railsui_charts/version"
require "active_support/core_ext/object/json"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/date/calculations"
require "active_support/core_ext/time/calculations"

module RailsuiCharts
  autoload :Configuration, "railsui_charts/configuration"
  autoload :ApexOptionsBuilder, "railsui_charts/apex_options_builder"
  autoload :ChartHelper, "railsui_charts/chart_helper"
  autoload :MetricHelper, "railsui_charts/metric_helper"
  autoload :FilterHelper, "railsui_charts/filter_helper"
  autoload :Filters, "railsui_charts/filters"
  autoload :Interval, "railsui_charts/interval"

  mattr_accessor :config
  @@config = RailsuiCharts::Configuration.new

  def self.configure
    yield(config)
  end
end

require "railsui_charts/engine" if defined?(Rails)
