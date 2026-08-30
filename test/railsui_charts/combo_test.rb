# frozen_string_literal: true

require "test_helper"

class ComboTest < Minitest::Test
  REVENUE = { "Jan" => 32_000, "Feb" => 35_000, "Mar" => 42_000 }.freeze
  CHURN = { "Jan" => 4.2, "Feb" => 3.8, "Mar" => 3.1 }.freeze

  def combo(**overrides)
    RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Revenue", data: REVENUE, type: :column, format: :short_currency },
        { name: "Churn rate", data: CHURN, type: :line, axis: :right, format: :percentage }
      ],
      **overrides
    ).build
  end

  def test_each_series_keeps_its_own_shape
    series = combo[:series]

    assert_equal "bar", series[0][:type]
    assert_equal "line", series[1][:type]
  end

  def test_the_chart_itself_stays_a_line
    # Apex draws every series as bars if the chart-level type says bar,
    # whatever the series asked for.
    assert_equal "line", combo.dig(:chart, :type)
  end

  def test_an_ordinary_chart_names_no_series_type
    # Naming one on every series would override the chart-level type and make
    # `type:` quietly do nothing.
    config = RailsuiCharts::ApexOptionsBuilder.new(REVENUE, type: :area).build

    refute config[:series].first.key?(:type)
    assert_equal "area", config.dig(:chart, :type)
  end

  def test_a_second_scale_hangs_on_the_right
    axes = combo[:yaxis]

    assert_kind_of Array, axes
    refute axes[0][:opposite]
    assert axes[1][:opposite]
  end

  def test_both_scales_survive_the_mobile_breakpoint
    # The breakpoint used to hand back a single axis object, which drops the
    # seriesName on each one and leaves Apex drawing every series against one
    # scale. Two series an order of magnitude apart then read as a flat line.
    mobile = combo.dig(:responsive, 0, :options, :yaxis)

    assert_kind_of Array, mobile
    assert_equal ["Revenue", "Churn rate"], mobile.map { |axis| axis[:seriesName] }
    refute mobile[0][:opposite]
    assert mobile[1][:opposite]
    assert_includes mobile.first.dig(:labels, :style, :fontSize), "font-size-sm"
  end

  def test_only_one_ruler_is_drawn_per_side
    # Three series, two of them sharing the left scale. Drawing a second left
    # ruler stacks two identical scales and reads as a fault.
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Revenue", data: REVENUE, type: :column },
        { name: "Costs", data: REVENUE, type: :column },
        { name: "Churn", data: CHURN, type: :line, axis: :right }
      ]
    ).build

    assert_equal [true, false, true], config[:yaxis].map { |axis| axis[:show] }
  end

  def test_each_axis_carries_its_own_format
    axes = combo[:yaxis]

    assert_equal :short_currency, axes[0][:format]
    assert_equal :percentage, axes[1][:format]
  end

  def test_an_axis_falls_back_to_the_chart_format
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Revenue", data: REVENUE, type: :column },
        { name: "Costs", data: REVENUE, type: :line, axis: :right }
      ],
      format: :currency
    ).build

    assert_equal [:currency, :currency], config[:yaxis].map { |axis| axis[:format] }
  end

  def test_the_tooltip_gets_a_format_per_series
    # A currency row and a percentage row in the same tooltip cannot share one
    # formatter without one of them reading in the wrong units.
    assert_equal %i[short_currency percentage], combo[:series_formats]
  end

  def test_both_scales_take_the_same_tick_count
    # Their gridlines have to land on each other. Picked independently, Apex
    # draws two interleaved sets, which is the tell of a hand-built chart.
    counts = combo[:yaxis].map { |axis| axis[:tickAmount] }

    assert_equal 1, counts.uniq.length, "the two scales are cut differently and their gridlines will interleave"
    assert_equal RailsuiCharts::ApexOptionsBuilder::AXIS_INTERVALS, counts.first
  end

  def test_each_scale_is_fitted_to_its_own_values
    # Revenue tops out at 52,000. A fixed tick count with a coarse step ladder
    # rounds that to a 0–100,000 axis and the columns fill half the plot.
    left, right = combo[:yaxis]

    assert_equal 0, left[:min]
    assert_operator left[:max], :>=, 52_000
    assert_operator left[:max], :<, 80_000, "the left scale has far more headroom than its data needs"

    # Churn runs 3.1 to 4.2 and should not be squashed against a zero baseline.
    assert_operator right[:min], :>, 0
    assert_operator right[:max], :>=, 4.2
  end

  def test_a_column_scale_reaches_its_baseline
    # Bars grow from zero. Starting the axis at the smallest value leaves them
    # floating and makes a 10% difference look like a fivefold one.
    assert_equal 0, combo[:yaxis].first[:min]
  end

  def test_a_line_alone_on_a_side_is_not_forced_to_zero
    # Forcing zero on a rate hovering near 3% flattens it against the top.
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Churn", data: CHURN, type: :line },
        { name: "Refunds", data: CHURN, type: :line, axis: :right }
      ]
    ).build

    assert_operator config[:yaxis].first[:min], :>, 0
  end

  def test_each_axis_uses_neutral_chart_ink
    colors = combo[:yaxis].map { |axis| axis.dig(:labels, :style, :colors) }

    assert_equal [RailsuiCharts.config.colors[:text]] * 2, colors
    assert_equal RailsuiCharts.config.series_colors.length, 8
  end

  def test_one_scale_keeps_the_quiet_neutral
    # Nothing to tell apart, so colouring it would be decoration.
    config = RailsuiCharts::ApexOptionsBuilder.new(REVENUE, type: :area).build

    assert_equal RailsuiCharts.config.colors[:text], config.dig(:yaxis, :labels, :style, :colors)
  end

  def test_a_combo_still_gets_a_legend_and_a_shared_tooltip
    assert combo.dig(:legend, :show)
    assert combo.dig(:tooltip, :shared)
  end

  def test_string_keys_are_accepted
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { "name" => "Revenue", "data" => REVENUE, "type" => "column" },
        { "name" => "Churn", "data" => CHURN, "type" => "line", "axis" => "right" }
      ]
    ).build

    assert_equal %w[bar line], config[:series].map { |s| s[:type] }
    assert config[:yaxis][1][:opposite]
  end

  def test_the_accessibility_table_still_covers_every_series
    html = ComboHelperTest.new(:test).render_combo

    assert_includes html, "Revenue"
    assert_includes html, "Churn rate"
  end

  def test_a_sub_unit_scale_survives_the_trip_to_the_browser
    # An Integer raised to a negative Integer is a Rational in Ruby, and a
    # Rational reaches the browser as "5/2". Apex drops a bound it cannot read
    # and auto-scales instead, which clipped the top of the data silently.
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Revenue", data: REVENUE, type: :column },
        { name: "Churn", data: CHURN, type: :line, axis: :right }
      ]
    ).build

    config[:yaxis].each do |axis|
      assert_kind_of Numeric, axis[:min]
      assert_kind_of Numeric, axis[:max]
      refute_kind_of Rational, axis[:min]
      refute_kind_of Rational, axis[:max]
    end

    # And it round-trips as a number rather than a string.
    parsed = JSON.parse(config.to_json)
    parsed["yaxis"].each { |axis| assert_kind_of Numeric, axis["max"] }
  end

  def test_no_scale_clips_its_own_data
    left, right = combo[:yaxis]

    assert_operator left[:max], :>=, REVENUE.values.max
    assert_operator right[:max], :>=, CHURN.values.max
    assert_operator right[:min], :<=, CHURN.values.min
  end

end

class ComboHelperTest < Minitest::Test
  def render_combo
    railsui_chart(
      [
        { name: "Revenue", data: { "Jan" => 32_000 }, type: :column, format: :short_currency },
        { name: "Churn rate", data: { "Jan" => 4.2 }, type: :line, axis: :right, format: :percentage }
      ]
    )
  end

  def test_a_combo_renders_through_the_ordinary_helper
    assert_includes render_combo, 'data-controller="railsui-chart"'
  end
  def test_a_complex_combo_keeps_an_axis_it_was_given
    # Apex reads xaxis.categories ahead of everything else. Without one it sets
    # the axis from the first series alone (Data.js: gl.labels = gl.labels[0]),
    # so a forecast whose band is drawn first would put next November first and
    # draw the history on top of it.
    RailsuiCharts.config.register_type(:range_area, points: :complex)

    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "Range", type: :range_area, data: [{ x: "Nov", y: [3, 5] }] },
      { name: "Actual", type: :line, data: [{ x: "Sep", y: 1 }, { x: "Oct", y: 2 }] }
    ], type: :line, categories: %w[Sep Oct Nov]).build

    assert_equal %w[Sep Oct Nov], config.dig(:xaxis, :categories)
  end

  def test_a_complex_combo_still_derives_no_axis_of_its_own
    RailsuiCharts.config.register_type(:range_area, points: :complex)

    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "Range", type: :range_area, data: [{ x: "Nov", y: [3, 5] }] },
      { name: "Actual", type: :line, data: [{ x: "Sep", y: 1 }] }
    ], type: :line).build

    # Handing Apex a derived list alongside numeric pair data makes it plot
    # nothing at all, so absent an explicit axis there is still none.
    assert_nil config.dig(:xaxis, :categories)
  end

end
