# frozen_string_literal: true

require "test_helper"
require "json"

# The gem ships its JavaScript two ways — an npm package for bundled apps and a
# prebuilt file for importmap apps — and both have to describe the same version
# of the same controllers. Nothing at runtime notices when they drift; a chart
# just quietly fails to appear.
class PackagingTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  BUNDLE = File.join(ROOT, "app/assets/javascripts/railsui_charts.js")
  INDEX = File.join(ROOT, "app/javascript/railsui_charts/index.js")

  # The identifiers the Ruby helpers put in data-controller. If one is renamed
  # on either side, that chart stops initialising with nothing in the console.
  IDENTIFIERS = %w[railsui-chart railsui-chart-filters railsui-metric-dialog].freeze

  def package
    JSON.parse(File.read(File.join(ROOT, "package.json")))
  end

  def test_the_package_version_matches_the_gem
    assert_equal RailsuiCharts::VERSION, package["version"],
      "package.json and the gem must ship as one thing — bin/release writes both"
  end

  def test_the_package_is_scoped_to_the_organisation
    assert_equal "@getrailsui/charts", package["name"]
  end

  # Bundled apps supply these; the gem must not carry its own copy, or an app
  # ends up with two Stimulus instances and controllers that never connect.
  def test_stimulus_and_apexcharts_are_peers_rather_than_dependencies
    assert package["peerDependencies"].key?("@hotwired/stimulus")
    assert package["peerDependencies"].key?("apexcharts")
    assert_nil package["dependencies"], "the package should have no runtime dependencies of its own"
  end

  def test_every_identifier_the_helpers_emit_is_registered
    index = File.read(INDEX)

    IDENTIFIERS.each do |identifier|
      assert_includes index, %("#{identifier}"), "#{identifier} is emitted by the helpers but never registered"
    end
  end

  def test_the_importmap_build_exists_and_carries_every_controller
    assert File.exist?(BUNDLE), "run `yarn build` — importmap apps are served this file"

    built = File.read(BUNDLE)
    IDENTIFIERS.each { |identifier| assert_includes built, %("#{identifier}") }
  end

  # The build has to leave these alone. Inlining them would ship a second copy
  # of Stimulus to every importmap app, and the app's own pins would be ignored.
  def test_the_build_leaves_its_peers_external
    built = File.read(BUNDLE)

    assert_match(/^import .* from "@hotwired\/stimulus";$/, built)
    assert_match(/^import .* from "apexcharts";$/, built)
  end

  # A stale build is the failure this whole release exists to prevent, one step
  # further along: the gem updates, the file served to importmap apps does not.
  def test_the_build_is_not_older_than_the_controllers
    sources = Dir[File.join(ROOT, "app/javascript/**/*.js")].reject { |f| f == BUNDLE }
    newest = sources.map { |f| File.mtime(f) }.max

    assert File.mtime(BUNDLE) >= newest,
      "app/assets/javascripts/railsui_charts.js is older than the controllers — run `yarn build`"
  end

  def test_the_importmap_pin_names_the_built_file
    pins = File.read(File.join(ROOT, "config/importmap.rb"))

    assert_includes pins, %(pin "@getrailsui/charts", to: "railsui_charts.js")
  end
end
