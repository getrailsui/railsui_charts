# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"

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
  #
  # Checked by rebuilding and comparing bytes, rather than by comparing mtimes
  # as this once did. Git does not record mtime — every file in a fresh clone
  # carries the time of the checkout — so the old assertion said nothing on CI
  # or on any machine that had just cloned, which is to say wherever it would
  # have mattered. Skipped rather than failed where esbuild is absent, so a
  # Ruby-only contributor can still run the suite; CI installs it.
  def test_the_build_matches_the_controllers
    esbuild = File.join(ROOT, "node_modules/.bin/esbuild")
    skip "esbuild is not installed — run `yarn install`" unless File.executable?(esbuild)

    Dir.mktmpdir do |dir|
      rebuilt = File.join(dir, "railsui_charts.js")
      ok = system(
        esbuild, File.join(ROOT, "app/javascript/railsui_charts/index.js"),
        "--bundle", "--format=esm",
        "--external:@hotwired/stimulus", "--external:apexcharts",
        "--outfile=#{rebuilt}",
        out: File::NULL, err: File::NULL
      )
      assert ok, "esbuild failed to rebuild the bundle"

      assert_equal File.read(rebuilt), File.read(BUNDLE),
        "app/assets/javascripts/railsui_charts.js does not match the controllers — run `yarn build`"
    end
  end

  # The stylesheet has two ways in: the asset pipeline, for every application,
  # and this export, for one that would rather pull it into its own Tailwind
  # build. The export is the fragile one — nothing at runtime notices a package
  # subpath that stops resolving, and the symptom is unstyled charts.
  def test_the_stylesheet_is_exported_from_the_package
    target = package.dig("exports", "./styles.css")

    refute_nil target, "the package must export ./styles.css for Tailwind applications"
    assert File.exist?(File.join(ROOT, target)),
      "./styles.css exports #{target}, which the repository does not have"
  end

  def test_the_published_package_carries_the_stylesheet
    assert_includes package["files"], "app/assets/stylesheets",
      "the stylesheet is exported but would not be published"
  end

  def test_the_importmap_pin_names_the_built_file
    pins = File.read(File.join(ROOT, "config/importmap.rb"))

    assert_includes pins, %(pin "@getrailsui/charts", to: "railsui_charts.js")
  end
end
