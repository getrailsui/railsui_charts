# frozen_string_literal: true
require_relative "lib/railsui_charts/version"

Gem::Specification.new do |spec|
  spec.name = "railsui_charts"
  spec.version = RailsuiCharts::VERSION
  spec.authors = ["Andy Leverenz"]
  spec.email = ["railsui@justalever.com"]
  spec.summary = "Rails-native chart components for RailsUI"
  spec.description = "Production-ready chart and metric components for Rails, built on ApexCharts. Server-rendered, accessible, and designed for Tailwind CSS."
  spec.homepage = "https://railsui.com/charts"
  spec.metadata = {
    "homepage_uri" => "https://railsui.com/charts",
    "documentation_uri" => "https://railsui.com/docs/charts",
    "source_code_uri" => "https://github.com/getrailsui/railsui_charts",
    "changelog_uri" => "https://github.com/getrailsui/railsui_charts/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/getrailsui/railsui_charts/issues",
    # Refuses a push from an account without multi-factor auth, which is the
    # attack this gem would otherwise be a route for: it is a dependency.
    "rubygems_mfa_required" => "true"
  }
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "README.md", "LICENSE.md", "CHANGELOG.md", "Rakefile"].reject do |f|
      File.directory?(f) || f.match(%r{\A(?:test|spec|features)/})
    end
  end
  spec.required_ruby_version = ">= 2.7.0"
  spec.require_paths = ["lib"]
  spec.license = "MIT"

  spec.add_dependency "rails", ">= 7.0"
end
