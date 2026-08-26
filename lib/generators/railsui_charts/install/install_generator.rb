require "rails/generators"

module RailsuiCharts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      # The JavaScript is no longer copied. It used to be, and that meant
      # `bundle update` moved the Ruby while the controllers stayed on whatever
      # version was installed — a fix could ship and reach nobody. Bundled apps
      # take it from npm, importmap apps from the pin this engine adds, and both
      # follow the gem from then on.
      #
      # The stylesheet now follows the same rule, for the same reason and after
      # the same mistake. See remove_broken_css_import.

      LAYOUT = "app/views/layouts/application.html.erb"
      TAILWIND_ENTRY = "app/assets/tailwind/application.css"
      STYLESHEET_TAG = %q(<%= stylesheet_link_tag "railsui_charts" %>).freeze

      # What 0.1.0 through 0.2.2 wrote into the Tailwind entry. It never worked.
      # Relative to app/assets/tailwind it names app/stylesheets — not the
      # application's own app/assets/stylesheets, and certainly not the file it
      # was after, which lives inside the gem where no relative path from the
      # application can reach it. Tailwind does not quietly skip an import it
      # cannot resolve; it fails the build. So this is removed rather than
      # corrected, from anyone who ran the old generator.
      BROKEN_IMPORT = %r{^@import\s+"\.\./\.\./stylesheets/railsui_charts";?[ \t]*\r?\n}.freeze

      def remove_broken_css_import
        path = File.join(destination_root, TAILWIND_ENTRY)
        return unless File.exist?(path)

        contents = File.read(path)
        return unless contents.match?(BROKEN_IMPORT)

        File.write(path, contents.sub(BROKEN_IMPORT, ""))
        say "✓ Removed the unresolvable @import from #{TAILWIND_ENTRY}", :green
        say "  It named a path that does not exist and failed the Tailwind build.", :yellow
      end

      # Served from the gem through the asset pipeline, which already carries it:
      # the engine puts app/assets/stylesheets on the load path and precompiles
      # the file. Nothing is copied, so `bundle update` moves the CSS too.
      def add_stylesheet_link
        path = File.join(destination_root, LAYOUT)

        unless File.exist?(path)
          say "⚠️  #{LAYOUT} not found. Add this to your layout's <head>:", :yellow
          say "  #{STYLESHEET_TAG}"
          return
        end

        contents = File.read(path)

        if contents.include?(%("railsui_charts"))
          say "✓ Rails UI Charts stylesheet already linked", :green
          return
        end

        unless contents.match?(%r{</head>})
          say "⚠️  No </head> found in #{LAYOUT}. Add this to your layout's <head>:", :yellow
          say "  #{STYLESHEET_TAG}"
          return
        end

        inject_into_file LAYOUT, "    #{STYLESHEET_TAG}\n", before: %r{^[ \t]*</head>}
        say "✓ Linked the Rails UI Charts stylesheet in #{LAYOUT}", :green
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
        elsif File.exist?(File.join(destination_root, TAILWIND_ENTRY))
          say "Prefer the CSS inside your Tailwind build? Once the package is", :cyan
          say "installed you can drop the stylesheet_link_tag and import it:", :cyan
          say ""
          say "  /* #{TAILWIND_ENTRY} */", :cyan
          say '  @import "@getrailsui/charts/styles.css";', :cyan
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
