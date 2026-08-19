require "rails/generators"

module RailsuiCharts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      # The JavaScript is no longer copied. It used to be, and that meant
      # `bundle update` moved the Ruby while the controllers stayed on whatever
      # version was installed — a fix could ship and reach nobody. Bundled apps
      # take it from npm, importmap apps from the pin this engine adds, and both
      # follow the gem from then on.
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

      def print_next_steps
        say ""
        say "RailsUI Charts #{RailsuiCharts::VERSION} installed.", :green
        say ""

        if importmap?
          say "Your importmap already has the controllers — this engine pins them.", :cyan
          say "Register them in app/javascript/controllers/index.js:", :cyan
        else
          say "Add the JavaScript package and ApexCharts:", :cyan
          say "  yarn add @getrailsui/charts apexcharts", :cyan
          say ""
          say "Then register the controllers in app/javascript/controllers/index.js:", :cyan
        end

        say ""
        say '  import { registerRailsuiCharts } from "@getrailsui/charts"', :cyan
        say "  registerRailsuiCharts(application)", :cyan
        say ""

        if importmap?
          say "ApexCharts is a peer dependency; pin it too:", :cyan
          say '  pin "apexcharts", to: "https://esm.sh/apexcharts@3.45.2"', :cyan
          say ""
        end

        say "Then use <%= railsui_chart data, type: :area %> in your views.", :cyan
        say ""
      end

      private

      def importmap?
        File.exist?(File.join(destination_root, "config/importmap.rb"))
      end
    end
  end
end
