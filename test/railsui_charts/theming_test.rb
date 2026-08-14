# frozen_string_literal: true

require "test_helper"

class ThemingTest < Minitest::Test
  SERIES = { "Jan" => 10, "Feb" => 20, "Mar" => 30 }.freeze

  def teardown
    # The config is global, so a test that changes it has to put it back or the
    # next one inherits a theme it never asked for. Through the writer, not by
    # poking an ivar: mattr_accessor is backed by @@config, so setting @config
    # resets nothing at all and does it silently.
    RailsuiCharts.config = RailsuiCharts::Configuration.new
  end

  def build(type: :line, **options)
    RailsuiCharts::ApexOptionsBuilder.new(SERIES, type: type, **options).build
  end

  def test_type_ships_as_a_variable_the_browser_resolves
    # Not baked to a number on the server: the controller reads it off the
    # chart's own computed style, so a dense card can shrink its own charts
    # without a second configuration.
    config = build

    assert_equal "var(--rui-chart-font-size, 12px)", config.dig(:xaxis, :labels, :style, :fontSize)
    assert_equal "var(--rui-chart-font-family, inherit)", config.dig(:chart, :fontFamily)
  end

  def test_the_compact_breakpoint_takes_the_smaller_step
    mobile = build.dig(:responsive).first[:options]

    assert_equal "var(--rui-chart-font-size-sm, 11px)", mobile.dig(:legend, :fontSize)
    assert_equal "var(--rui-chart-font-size-sm, 11px)", mobile.dig(:xaxis, :labels, :style, :fontSize)
  end

  def test_type_can_be_replaced_outright
    RailsuiCharts.config.typography[:size] = "0.7rem"

    assert_equal "0.7rem", build.dig(:xaxis, :labels, :style, :fontSize)
  end

  def test_geometry_ships_as_numbers_not_variables
    # Apex does arithmetic on these. A CSS variable resolves to a string, and
    # "4" + 1 is "41", so they cannot ride the same channel the type does.
    radius = build(type: :column).dig(:plotOptions, :bar, :borderRadius)

    assert_kind_of Numeric, radius
    assert_equal 4, radius
    assert_equal 2, build.dig(:stroke, :width)
  end

  def test_geometry_is_configurable
    RailsuiCharts.config.geometry[:bar_radius] = 0
    RailsuiCharts.config.geometry[:stroke_width] = 3

    assert_equal 0, build(type: :column).dig(:plotOptions, :bar, :borderRadius)
    assert_equal 3, build.dig(:stroke, :width)
  end

  def test_marker_size_follows_the_configured_geometry
    RailsuiCharts.config.geometry[:marker_size] = 5

    assert_equal 5, build.dig(:markers, :size)
  end

  def test_a_comparison_keeps_both_periods_at_one_weight
    RailsuiCharts.config.geometry[:stroke_width] = 3
    config = build(compare: { "Jan" => 8, "Feb" => 12, "Mar" => 15 })

    # The dash is what separates them. Thinning the comparison as well would
    # say "less important" twice.
    assert_equal [3, 3], config.dig(:stroke, :width)
  end

  def test_no_font_size_is_left_hardcoded
    # A single literal left behind is a knob that silently does nothing.
    source = File.read(File.expand_path("../../lib/railsui_charts/apex_options_builder.rb", __dir__))

    refute_match(/fontSize: "\d+px"/, source)
    refute_match(/fontFamily: "inherit"/, source)
  end
end
