# frozen_string_literal: true

require "test_helper"

class MultiSeriesTest < Minitest::Test
  PLANS = [
    { name: "Starter", data: [{ x: "Jan", y: 10 }, { x: "Feb", y: 14 }] },
    { name: "Pro", data: [{ x: "Jan", y: 22 }, { x: "Feb", y: 26 }] },
    { name: "Enterprise", data: [{ x: "Jan", y: 8 }, { x: "Feb", y: 12 }] }
  ].freeze

  def build(data, **options)
    RailsuiCharts::ApexOptionsBuilder.new(data, **options).build
  end

  def test_named_series_plot_side_by_side
    config = build(PLANS, type: :column)

    assert_equal %w[Starter Pro Enterprise], config[:series].map { |s| s[:name] }
    assert_equal [10, 14], config[:series].first[:data]
    assert_equal %w[Jan Feb], config[:xaxis][:categories]
  end

  def test_a_bare_series_still_works
    config = build([1, 2, 3], type: :line, label: "Signups")

    assert_equal 1, config[:series].length
    assert_equal "Signups", config[:series].first[:name]
    assert_equal [1, 2, 3], config[:series].first[:data]
  end

  def test_series_form_is_told_apart_from_points
    # Points carry :y; series carry :data. Only the latter is a series list.
    refute RailsuiCharts::ApexOptionsBuilder.series_form?([{ x: "Jan", y: 1 }])
    assert RailsuiCharts::ApexOptionsBuilder.series_form?([{ name: "A", data: [1] }])
  end

  def test_each_series_takes_the_next_palette_slot
    config = build(PLANS, type: :column)

    assert_equal RailsuiCharts::Configuration::SERIES_FALLBACKS, config[:colors]
  end

  def test_two_or_more_series_always_carry_a_legend
    assert_equal true, build(PLANS, type: :column)[:legend][:show]
    # One series needs none — the title names it.
    assert_equal false, build([1, 2], type: :line)[:legend][:show]
  end

  def test_stacking_is_opt_in
    plain = build(PLANS, type: :column)
    stacked = build(PLANS, type: :column, stacked: true)

    refute plain[:chart][:stacked]
    assert_equal true, stacked[:chart][:stacked]
    assert_equal "normal", stacked[:chart][:stackType]
    # Segments separate with a gap in the surface colour, never a stroke.
    assert_equal 2, stacked[:stroke][:width]
  end

  def test_percent_stacking_switches_totals_for_share
    config = build(PLANS, type: :column, stacked: :percent)

    assert_equal "100%", config[:chart][:stackType]
  end

  def test_comparison_is_ignored_once_there_are_several_series
    # `compare:` overlays a previous period on one series; with several it has
    # nothing unambiguous to compare against.
    config = build(PLANS, type: :line, compare: [1, 2])

    assert_equal 3, config[:series].length
    refute config[:series].map { |s| s[:name] }.include?("Previous period")
  end

  def test_numeric_bounds_span_every_series
    data = [
      { name: "A", data: [{ x: 5, y: 5 }] },
      { name: "B", data: [{ x: 95, y: 90 }] }
    ]
    config = build(data, type: :scatter)

    assert_operator config[:xaxis][:min], :<=, 5
    assert_operator config[:xaxis][:max], :>=, 95
  end

  def test_blank_sees_through_empty_series
    assert RailsuiCharts::ApexOptionsBuilder.blank?([{ name: "A", data: [] }])
    refute RailsuiCharts::ApexOptionsBuilder.blank?([{ name: "A", data: [0] }])
  end

  def test_the_accessible_table_gets_a_column_per_series
    html = railsui_chart(PLANS, type: :column)

    assert_includes html, "<th>Starter</th>"
    assert_includes html, "<th>Pro</th>"
    assert_includes html, "<th>Enterprise</th>"
    assert_includes html, "<td>Jan</td>"
  end

  def test_small_multiples_render_one_chart_per_series
    html = railsui_small_multiples(PLANS, type: :area, columns: 3)

    assert_includes html, "railsui-small-multiples"
    assert_equal 3, html.scan("railsui-small-multiple__title").length
    assert_includes html, "Starter"
    assert_includes html, "--rui-small-multiple-columns: 3"
  end

  def test_small_multiples_share_one_scale
    html = railsui_small_multiples(PLANS, type: :area)

    # Values run 8..26 across the three series. Left to themselves each facet
    # would fit its own data and a small series would look like a large one.
    # Twice per facet: once on the axis, once on the mobile breakpoint that
    # carries it, since a scale that only held at desktop would not be shared.
    assert_equal 6, html.scan("&quot;min&quot;:8,&quot;max&quot;:26").length
  end

  def test_small_multiples_do_not_spend_a_hue_per_facet
    html = railsui_small_multiples(PLANS, type: :area)

    # The title carries identity, so every facet takes the same colour.
    assert_equal 3, html.scan("--rui-chart-primary").length
  end

  def test_small_multiples_fall_back_to_the_empty_panel
    assert_includes railsui_small_multiples([], type: :area), "railsui-chart-state--empty"
  end
  def test_series_with_different_labels_share_one_axis
    # Categories used to come from the first series alone, so any later series
    # was drawn from position zero: a projection labelled November landed on
    # January, on top of the history it was supposed to follow.
    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "Actual", data: [{ x: "Sep", y: 1 }, { x: "Oct", y: 2 }] },
      { name: "Forecast", data: [{ x: "Nov", y: 3 }] }
    ], type: :line).build

    assert_equal %w[Sep Oct Nov], config.dig(:xaxis, :categories)
    assert_equal [1, 2, nil], config[:series][0][:data]
    assert_equal [nil, nil, 3], config[:series][1][:data]
  end

  def test_series_sharing_labels_are_left_exactly_as_they_were
    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "A", data: [{ x: "Sep", y: 1 }, { x: "Oct", y: 2 }] },
      { name: "B", data: [{ x: "Sep", y: 3 }, { x: "Oct", y: 4 }] }
    ], type: :line).build

    assert_equal %w[Sep Oct], config.dig(:xaxis, :categories)
    assert_equal [1, 2], config[:series][0][:data]
    assert_equal [3, 4], config[:series][1][:data]
  end

  def test_partly_overlapping_series_line_up_on_the_labels_they_share
    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "A", data: [{ x: "Sep", y: 1 }, { x: "Oct", y: 2 }] },
      { name: "B", data: [{ x: "Oct", y: 9 }, { x: "Nov", y: 8 }] }
    ], type: :line).build

    assert_equal %w[Sep Oct Nov], config.dig(:xaxis, :categories)
    assert_equal [nil, 9, 8], config[:series][1][:data]
  end

  def test_an_explicit_axis_decides_the_order_series_are_aligned_to
    config = RailsuiCharts::ApexOptionsBuilder.new([
      { name: "Forecast", data: [{ x: "Nov", y: 3 }] },
      { name: "Actual", data: [{ x: "Sep", y: 1 }, { x: "Oct", y: 2 }] }
    ], type: :line, categories: %w[Sep Oct Nov]).build

    # Left to first appearance this would read Nov, Sep, Oct — a forecast drawn
    # before the history it continues.
    assert_equal %w[Sep Oct Nov], config.dig(:xaxis, :categories)
    assert_equal [nil, nil, 3], config[:series][0][:data]
    assert_equal [1, 2, nil], config[:series][1][:data]
  end

end
