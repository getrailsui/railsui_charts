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

  # The legend markers read as indented against the axis labels and the heading
  # above them, because Apex insets a left-aligned legend by its own chrome and
  # padding before the first item's margin applies. Measured on a rendered
  # chart: offsetX 0 puts the marker 36px in with an 8px item gap.
  def test_the_legend_starts_where_the_rest_of_the_card_starts
    assert_equal(-36, two_series_options[:legend][:offsetX])
  end

  # The mobile override tightens the gap between items, which moves the first
  # one too. Without a matching correction the legend lands 2px left of where
  # the desktop one does.
  def test_the_mobile_legend_corrects_for_its_tighter_item_gap
    mobile = two_series_options[:responsive].first[:options][:legend]

    assert_equal 6, mobile[:itemMargin][:horizontal]
    assert_equal(-34, mobile[:offsetX])
  end

  private

  def two_series_options
    RailsuiCharts::ApexOptionsBuilder.new(
      [{ name: "This year", data: [1, 2] }, { name: "Last year", data: [2, 3] }],
      type: :area
    ).build
  end
end
