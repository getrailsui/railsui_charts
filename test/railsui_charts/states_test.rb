# frozen_string_literal: true

require "test_helper"

class StatesTest < Minitest::Test
  def test_blank_recognises_nothing_to_plot
    assert RailsuiCharts::ApexOptionsBuilder.blank?(nil)
    assert RailsuiCharts::ApexOptionsBuilder.blank?([])
    assert RailsuiCharts::ApexOptionsBuilder.blank?({})
    assert RailsuiCharts::ApexOptionsBuilder.blank?([nil, nil])
    assert RailsuiCharts::ApexOptionsBuilder.blank?([{ x: "Jan", y: nil }])
  end

  def test_zeroes_are_data_not_absence
    # A quiet day still has something to say, and a flat line at zero is the
    # correct way to say it.
    refute RailsuiCharts::ApexOptionsBuilder.blank?([0, 0, 0])
    refute RailsuiCharts::ApexOptionsBuilder.blank?([{ x: "Jan", y: 0 }])
    refute RailsuiCharts::ApexOptionsBuilder.blank?({ "Jan" => 0 })
  end

  def test_blank_data_renders_an_empty_panel_instead_of_bare_axes
    html = railsui_chart([], type: :line, height: 340)

    assert_includes html, "railsui-chart-state--empty"
    assert_includes html, "No data"
    assert_includes html, "min-height: 340px"
    refute_includes html, "data-controller=\"railsui-chart\""
  end

  def test_empty_message_can_be_a_string_or_a_hash
    assert_includes railsui_chart([], empty: "No revenue yet"), "No revenue yet"

    html = railsui_chart([], empty: { title: "No revenue yet", description: "Charges show up here." })
    assert_includes html, "No revenue yet"
    assert_includes html, "Charges show up here."
  end

  def test_skeleton_holds_the_footprint_and_announces_itself
    html = railsui_chart_skeleton(height: 280)

    assert_includes html, "railsui-chart-state--loading"
    assert_includes html, "min-height: 280px"
    assert_includes html, 'aria-busy="true"'
    assert_includes html, "railsui-chart-skeleton"
  end

  def test_error_state_reads_as_a_failure_not_an_absence
    html = railsui_chart_error(description: "The query timed out.")

    assert_includes html, "railsui-chart-state--error"
    # The apostrophe arrives HTML-escaped, as it should.
    assert_includes html, "load this chart"
    assert_includes html, "The query timed out."
  end

  def test_a_metric_card_without_history_keeps_its_shape
    html = railsui_metric_card(label: "MRR", value: 0, previous: 0, format: :currency, history: [], chart_height: 180)

    # The card still reports its value; only the plot is absent.
    assert_includes html, "railsui-metric-card"
    assert_includes html, "$0.00"
    assert_includes html, "railsui-chart-state--empty"
    assert_includes html, "min-height: 180px"
  end
end
