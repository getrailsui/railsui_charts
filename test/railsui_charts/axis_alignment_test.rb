# frozen_string_literal: true

require "test_helper"

class AxisAlignmentTest < Minitest::Test
  SERIES = { "Jan" => 32_000, "Feb" => 48_000 }.freeze

  def offset_for(**options)
    RailsuiCharts::ApexOptionsBuilder.new(SERIES, **options).build.dig(:yaxis, :labels, :offsetX)
  end

  def test_a_value_axis_is_pulled_out_to_the_edge
    # Apex reserves a gutter beside the labels. Inside a card that reads as the
    # chart being indented from the heading above it.
    assert_equal(-RailsuiCharts::ApexOptionsBuilder::AXIS_LABEL_GUTTER, offset_for(type: :line))
  end

  def test_a_right_hand_axis_is_pulled_the_same_way
    # Apex mirrors offsetX for an opposite axis, so the sign stays negative —
    # flipping it moved the labels further inward rather than out.
    assert_operator offset_for(type: :line, axis: :right), :<, 0
  end

  def test_a_category_axis_is_left_alone
    # A horizontal bar puts names on the y-axis and Apex sizes that column to
    # the text, so only the grid padding sits outside it. Cancelling the full
    # gutter here pushed the longest name twelve pixels past the card edge.
    assert_equal(-RailsuiCharts::ApexOptionsBuilder::CATEGORY_AXIS_GUTTER, offset_for(type: :bar))
  end

  def test_a_timeline_is_left_alone_too
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [{ x: "api", from: Time.utc(2026, 8, 1), to: Time.utc(2026, 8, 2) }], type: :range_bar
    ).build

    assert_equal(-RailsuiCharts::ApexOptionsBuilder::CATEGORY_AXIS_GUTTER, config.dig(:yaxis, :labels, :offsetX))
  end

  def test_both_scales_of_a_combo_reach_their_own_edge
    config = RailsuiCharts::ApexOptionsBuilder.new(
      [
        { name: "Revenue", data: SERIES, type: :column },
        { name: "Churn", data: { "Jan" => 4.2, "Feb" => 3.1 }, type: :line, axis: :right }
      ]
    ).build

    config[:yaxis].each { |axis| assert_operator axis.dig(:labels, :offsetX), :<, 0 }
  end
end
