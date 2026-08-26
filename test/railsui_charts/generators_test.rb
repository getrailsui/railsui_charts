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

  GEM_ROOT = File.expand_path("../..", __dir__)
  GENERATOR = RailsuiCharts::Generators::InstallGenerator

  LAYOUT = <<~ERB
    <!DOCTYPE html>
    <html>
      <head>
        <%= stylesheet_link_tag "application" %>
      </head>
      <body><%= yield %></body>
    </html>
  ERB

  def with_layout(contents = LAYOUT)
    path = File.join(destination_root, "app/views/layouts")
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "application.html.erb"), contents)
  end

  def with_tailwind_css(contents = %(@import "tailwindcss";\n))
    path = File.join(destination_root, "app/assets/tailwind")
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "application.css"), contents)
  end

  def layout_contents
    File.read(File.join(destination_root, "app/views/layouts/application.html.erb"))
  end

  # The assertion the previous version of this test was missing, and the reason
  # the installer shipped broken for five releases: it asserted the generator
  # had written the string the generator writes, which is true of any string it
  # could possibly have written. What matters is whether the name it emits
  # resolves to a file that actually gets served.
  def test_the_name_the_layout_asks_for_is_a_file_the_gem_ships
    logical = GENERATOR::STYLESHEET_TAG[/stylesheet_link_tag "([^"]+)"/, 1]
    served = File.join(GEM_ROOT, "app/assets/stylesheets", "#{logical}.css")

    assert File.exist?(served),
      "the layout asks for #{logical.inspect}, which the gem does not ship at #{served}"
  end

  # Whatever the engine precompiles has to be the same name, or the asset is on
  # the load path in development and missing from a production build.
  def test_the_engine_precompiles_the_name_the_layout_asks_for
    logical = GENERATOR::STYLESHEET_TAG[/stylesheet_link_tag "([^"]+)"/, 1]
    engine = File.read(File.join(GEM_ROOT, "lib/railsui_charts/engine.rb"))

    assert_includes engine, %(precompile << "#{logical}.css")
  end

  def test_it_links_the_stylesheet_in_the_layout
    with_layout
    run_generator

    assert_includes layout_contents, %(<%= stylesheet_link_tag "railsui_charts" %>)
  end

  def test_it_links_the_stylesheet_inside_the_head
    with_layout
    run_generator

    head = layout_contents[/<head>(.*?)<\/head>/m, 1]

    assert_includes head.to_s, "railsui_charts"
  end

  def test_it_does_not_link_the_stylesheet_twice
    with_layout
    run_generator
    run_generator

    assert_equal 1, layout_contents.scan(%(stylesheet_link_tag "railsui_charts")).length
  end

  def test_a_missing_layout_is_said_rather_than_created
    output = run_generator

    assert_match(/not found/, output)
    assert_no_file "app/views/layouts/application.html.erb"
  end

  # Guessing where the tag goes in a layout with no head is worse than saying so:
  # a stylesheet in the body still applies, but the reader gets a flash of
  # unstyled chart and no explanation.
  def test_a_layout_without_a_head_is_said_rather_than_guessed
    with_layout("<html><body><%= yield %></body></html>\n")
    output = run_generator

    assert_match(/No <\/head>/, output)
    assert_equal "<html><body><%= yield %></body></html>\n", layout_contents
  end

  # 0.1.0 through 0.2.2 wrote an @import that named app/stylesheets — a path
  # that is neither the application's own stylesheets nor the gem's. Tailwind
  # fails the build on an import it cannot resolve, so leaving it in place is
  # not a cosmetic problem, and upgrading has to take it back out.
  def test_it_removes_the_unresolvable_import_left_by_earlier_versions
    with_layout
    with_tailwind_css(%(@import "tailwindcss";\n@import "../../stylesheets/railsui_charts";\n))
    output = run_generator

    contents = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))

    refute_includes contents, "../../stylesheets/railsui_charts"
    assert_includes contents, %(@import "tailwindcss";)
    assert_match(/Removed the unresolvable @import/, output)
  end

  def test_it_leaves_an_unrelated_tailwind_entry_alone
    with_layout
    with_tailwind_css
    run_generator

    assert_equal %(@import "tailwindcss";\n),
      File.read(File.join(destination_root, "app/assets/tailwind/application.css"))
  end

  def test_it_no_longer_writes_a_css_import
    with_layout
    with_tailwind_css
    run_generator

    refute_includes File.read(File.join(destination_root, "app/assets/tailwind/application.css")),
      "railsui_charts"
  end

  # The whole point of 0.2.0: the controllers are no longer copied into the app,
  # because a copy is what `bundle update` could never move.
  def test_it_no_longer_copies_the_controllers
    with_layout
    run_generator

    assert_no_file "app/javascript/controllers/railsui_chart_controller.js"
  end

  def test_it_tells_a_bundled_app_to_add_the_package
    with_layout
    output = run_generator

    assert_match(/yarn add @getrailsui\/charts/, output)
    assert_match(/registerRailsuiCharts/, output)
  end

  # Offered rather than written: the import only resolves once the package is
  # installed, and writing it first would break the build the same way the old
  # one did.
  def test_it_offers_the_tailwind_import_to_an_app_that_has_a_tailwind_entry
    with_layout
    with_tailwind_css
    output = run_generator

    assert_match(%r{@import "@getrailsui/charts/styles\.css"}, output)
  end

  def test_it_does_not_offer_the_tailwind_import_without_a_tailwind_entry
    with_layout
    output = run_generator

    assert_no_match(%r{@getrailsui/charts/styles\.css}, output)
  end

  # An importmap app needs no package at all — the engine pins the build — so
  # telling it to run yarn would be a wrong turn rather than a redundant one.
  def test_it_tells_an_importmap_app_something_different
    with_layout
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/importmap.rb"), "pin \"application\"\n")

    output = run_generator

    assert_no_match(/yarn add/, output)
    assert_match(/pin "apexcharts"/, output)
    assert_match(/registerRailsuiCharts/, output)
  end
end
