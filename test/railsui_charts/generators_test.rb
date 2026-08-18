# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/railsui_charts/install/install_generator"
require "generators/railsui_charts/update/update_generator"

# The generators are the only way the JavaScript reaches an app, and a broken
# one fails at someone else's console rather than in this suite.
class GeneratorsTest < Rails::Generators::TestCase
  tests RailsuiCharts::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator", __dir__)
  setup :prepare_destination

  CONTROLLERS = RailsuiCharts::Generators::InstallGenerator::CONTROLLERS

  def test_install_copies_every_controller
    run_generator

    CONTROLLERS.each do |controller|
      assert_file "app/javascript/controllers/#{controller}"
    end
  end

  # Without the stamp there is no way to tell which version of the JavaScript an
  # app is running: the lockfile describes the Ruby, and this copy can be
  # arbitrarily older than it.
  def test_the_copy_says_which_version_it_came_from
    run_generator

    assert_file "app/javascript/controllers/railsui_chart_controller.js" do |body|
      assert_match(/railsui_charts #{Regexp.escape(RailsuiCharts::VERSION)}/, body)
      assert_match(/railsui_charts:update/, body, "the copy should say how to take a newer one")
    end
  end

  def test_the_copy_is_the_engine_controller_rather_than_a_second_copy_of_it
    run_generator

    shipped = File.read(File.expand_path("../../app/javascript/controllers/railsui_chart_controller.js", __dir__))

    assert_file "app/javascript/controllers/railsui_chart_controller.js" do |body|
      assert body.end_with?(shipped), "the installed file should be the engine's controller with a header on it"
    end
  end

  # The bug this whole path exists for: an app installed at one version, the
  # gem moved on, and bundle update left the JavaScript behind.
  def test_update_replaces_an_older_copy_without_asking
    run_generator
    path = File.join(destination_root, "app/javascript/controllers/railsui_chart_controller.js")
    File.write(path, "// railsui_charts 0.0.1\nconsole.log('stale')\n")

    capture(:stdout) do
      Rails::Generators.invoke("railsui_charts:update", [], destination_root: destination_root)
    end

    assert_file "app/javascript/controllers/railsui_chart_controller.js" do |body|
      assert_no_match(/stale/, body)
      assert_match(/railsui_charts #{Regexp.escape(RailsuiCharts::VERSION)}/, body)
    end
  end
end
