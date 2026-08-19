# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/railsui_charts/install/install_generator"

# The installer is the first thing anyone runs, and a broken one fails at
# someone else's console rather than in this suite.
class GeneratorsTest < Rails::Generators::TestCase
  tests RailsuiCharts::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator", __dir__)
  setup :prepare_destination

  def with_tailwind_css(contents = "@import \"tailwindcss\";\n")
    path = File.join(destination_root, "app/assets/tailwind")
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "application.css"), contents)
  end

  def test_it_adds_the_stylesheet_import
    with_tailwind_css
    run_generator

    assert_file "app/assets/tailwind/application.css", %r{@import "\.\./\.\./stylesheets/railsui_charts";}
  end

  def test_it_does_not_add_the_import_twice
    with_tailwind_css("@import \"tailwindcss\";\n@import \"../../stylesheets/railsui_charts\";\n")
    run_generator

    contents = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))

    assert_equal 1, contents.scan("stylesheets/railsui_charts").length
  end

  def test_a_missing_stylesheet_is_said_rather_than_created
    output = run_generator

    assert_match(/not found/, output)
    assert_no_file "app/assets/tailwind/application.css"
  end

  # The whole point of 0.2.0: the controllers are no longer copied into the app,
  # because a copy is what `bundle update` could never move.
  def test_it_no_longer_copies_the_controllers
    with_tailwind_css
    run_generator

    assert_no_file "app/javascript/controllers/railsui_chart_controller.js"
  end

  def test_it_tells_a_bundled_app_to_add_the_package
    with_tailwind_css
    output = run_generator

    assert_match(/yarn add @getrailsui\/charts/, output)
    assert_match(/registerRailsuiCharts/, output)
  end

  # An importmap app needs no package at all — the engine pins the build — so
  # telling it to run yarn would be a wrong turn rather than a redundant one.
  def test_it_tells_an_importmap_app_something_different
    with_tailwind_css
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/importmap.rb"), "pin \"application\"\n")

    output = run_generator

    assert_no_match(/yarn add/, output)
    assert_match(/pin "apexcharts"/, output)
    assert_match(/registerRailsuiCharts/, output)
  end
end
