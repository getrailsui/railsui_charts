# frozen_string_literal: true

module RailsuiCharts
  class Engine < ::Rails::Engine
    isolate_namespace RailsuiCharts

    initializer "railsui_charts.helpers" do
      ActiveSupport.on_load :action_controller do
        helper RailsuiCharts::ChartHelper
        helper RailsuiCharts::MetricHelper
        helper RailsuiCharts::FilterHelper
      end
    end

    initializer "railsui_charts.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.precompile << "railsui_charts.css"

      # The built controllers, served from the gem so an importmap application
      # can pin them instead of holding a copy that bundle update never moves.
      app.config.assets.paths << root.join("app/assets/javascripts")
      app.config.assets.precompile << "railsui_charts.js"
    end

    # Adds this gem's pins to the host app's importmap. `before` matters:
    # importmap-rails reads the collected paths in its own initializer, and a
    # pin added afterwards is simply never seen.
    initializer "railsui_charts.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
    end
  end
end
