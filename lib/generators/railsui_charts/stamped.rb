module RailsuiCharts
  module Generators
    # The version the copy was taken from, written into the copy.
    #
    # Without it there is no way to tell which version of the JavaScript an app
    # is actually running: the Gemfile.lock describes the Ruby, and the copied
    # controller can be arbitrarily older. It also makes the copy's status
    # obvious to whoever opens it next.
    def self.stamped(source_root, filename)
      body = File.read(File.join(source_root, filename))

      <<~HEADER + body
        // railsui_charts #{RailsuiCharts::VERSION}
        //
        // Copied from the gem by `rails g railsui_charts:install`. Edits here are
        // yours to keep, but they will be overwritten by
        // `rails g railsui_charts:update`, which is how you take a newer version
        // of this file — `bundle update` does not, because this copy is what your
        // bundler compiles.

      HEADER
    end
  end
end
