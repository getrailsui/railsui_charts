# frozen_string_literal: true

module RailsuiCharts
  class Engine < ::Rails::Engine
    isolate_namespace RailsuiCharts

    initializer "railsui_charts.helpers" do
      ActiveSupport.on_load :action_controller do
        helper RailsuiCharts::ChartHelper
        helper RailsuiCharts::MetricHelper
      end
    end

    initializer "railsui_charts.assets" do |app|
      app.config.assets.precompile << "railsui_charts.css"
    end
  end
end
