require "rails/generators"
require_relative "../stamped"

module RailsuiCharts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      # Points at the controllers the engine already ships rather than at a
      # `templates/` copy of them. A second copy is a second thing to remember
      # to fix, and the two drift the first time one of them is patched.
      source_root File.expand_path("../../../../app/javascript/controllers", __dir__)

      CONTROLLERS = %w[
        railsui_chart_controller.js
        railsui_chart_filters_controller.js
        railsui_metric_dialog_controller.js
      ].freeze

      # Written through the generator's own file actions rather than
      # Rails.root, so it lands under destination_root like everything else a
      # generator writes — and so it can be tested without booting an app.
      def add_css_import
        path = "app/assets/tailwind/application.css"
        import_statement = %q(@import "../../stylesheets/railsui_charts";)
        full_path = File.join(destination_root, path)

        unless File.exist?(full_path)
          say "⚠️  #{path} not found. Add this import manually:", :yellow
          say "  #{import_statement}"
          return
        end

        if File.read(full_path).include?(import_statement)
          say "✓ RailsUI Charts CSS import already present", :green
        else
          append_to_file path, "#{import_statement}\n"
          say "✓ Added RailsUI Charts CSS import to #{path}", :green
        end
      end

      def copy_stimulus_controllers
        CONTROLLERS.each do |controller|
          create_file "app/javascript/controllers/#{controller}",
                      RailsuiCharts::Generators.stamped(self.class.source_root, controller)
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
        say "After upgrading the gem, run `rails g railsui_charts:update`.", :cyan
        say "The controllers above are copies — bundle update does not touch them.", :cyan
        say ""
      end
    end
  end
end
