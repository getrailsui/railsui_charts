require "rails/generators"

module RailsuiCharts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def add_css_import
        application_css = Rails.root.join("app/assets/tailwind/application.css")

        if File.exist?(application_css)
          content = File.read(application_css)
          import_statement = '@import "../../stylesheets/railsui_charts";'

          unless content.include?(import_statement)
            File.write(application_css, "#{content.strip}\n#{import_statement}\n")
            say "✓ Added RailsUI Charts CSS import to app/assets/tailwind/application.css", :green
          else
            say "✓ RailsUI Charts CSS import already present", :green
          end
        else
          say "⚠️ app/assets/tailwind/application.css not found. Add this import manually:", :yellow
          say '  @import "../../stylesheets/railsui_charts";'
        end
      end

      CONTROLLERS = %w[
        railsui_chart_controller.js
        railsui_chart_filters_controller.js
        railsui_metric_dialog_controller.js
      ].freeze

      def copy_stimulus_controllers
        CONTROLLERS.each do |controller|
          copy_file controller, "app/javascript/controllers/#{controller}"
        end
      end

      def print_next_steps
        say ""
        say "RailsUI Charts installed.", :green
        say ""
        say "Next steps:", :cyan
        say "  1. Add the ApexCharts dependency for your JS setup:", :cyan
        say "     Build mode:  yarn add apexcharts", :cyan
        say "     No-build:    pin \"apexcharts\", to: \"https://esm.sh/apexcharts@3.45.2\"", :cyan
        say "  2. Use <%= railsui_chart data, type: :area %> in your views.", :cyan
        say ""
      end
    end
  end
end
