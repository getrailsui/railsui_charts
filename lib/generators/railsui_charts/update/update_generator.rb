require "rails/generators"
require_relative "../stamped"
require_relative "../install/install_generator"

module RailsuiCharts
  module Generators
    # Re-copies the Stimulus controllers after a gem upgrade.
    #
    # This exists because the JavaScript does not run from the gem. The install
    # generator copies each controller into the host app, the app's bundler
    # compiles that copy, and from then on the copy is what executes — so
    # `bundle update` moves the Ruby and silently leaves the JavaScript on
    # whatever version was installed. A fix shipped in a release reaches nobody
    # until this is run.
    class UpdateGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../app/javascript/controllers", __dir__)

      def overwrite_stimulus_controllers
        InstallGenerator::CONTROLLERS.each do |controller|
          # force, because the whole point is to replace an older copy, and
          # prompting once per file turns a routine upgrade into a quiz.
          create_file "app/javascript/controllers/#{controller}",
                      RailsuiCharts::Generators.stamped(self.class.source_root, controller),
                      force: true
        end

        say ""
        say "Chart controllers updated to railsui_charts #{RailsuiCharts::VERSION}.", :green
        say "Rebuild your JavaScript to pick them up.", :cyan
        say ""
      end
    end
  end
end
