# frozen_string_literal: true

require "test_helper"

class ChartHelperTest < Minitest::Test
  def test_renders_chart_container
    html = railsui_chart([10, 20, 30], type: :line)

    assert_includes html, 'data-controller="railsui-chart"'
    assert_includes html, '&quot;type&quot;:&quot;line&quot;'
    assert_includes html, 'class="railsui-chart"'
  end

  def test_renders_accessible_table
    html = railsui_chart([10, 20], type: :line, id: "revenue")

    assert_includes html, "Data for chart revenue"
    assert_includes html, '<table class="sr-only"'
  end

  def test_renders_metric
    html = railsui_metric(label: "Revenue", value: 1000, change: 12.5, format: :currency)

    assert_includes html, "Revenue"
    assert_includes html, "$1,000.00"
    assert_includes html, "+12.5%"
    assert_includes html, "railsui-metric-delta--positive"
  end

  def test_accessible_table_uses_categories_and_series_names
    html = railsui_chart([{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }], type: :line, label: "Revenue", id: "rev")

    assert_includes html, "<th>Category</th>"
    assert_includes html, "<th>Revenue</th>"
    assert_includes html, "<td>Jan</td>"
  end

  def test_accessible_table_includes_comparison_series
    html = railsui_chart([10, 20], type: :line, compare: [8, 16], label: "This week", compare_label: "Last week")

    assert_includes html, "<th>This week</th>"
    assert_includes html, "<th>Last week</th>"
  end

  def test_accessible_table_labels_comparison_categories
    html = railsui_chart(
      [{ x: "Aug 8", y: 10 }, { x: "Aug 9", y: 20 }],
      type: :line,
      compare: [{ x: "Aug 1", y: 8 }, { x: "Aug 2", y: 16 }],
      label: "This week",
      compare_label: "Last week"
    )

    assert_includes html, "<th>Comparison category</th>"
    assert_includes html, "<td>Aug 8</td><td>Aug 1</td><td>10</td><td>8</td>"
  end

  def test_renders_metric_card
    html = railsui_metric_card(
      label: "MRR",
      value: 18_450,
      previous: 17_200,
      format: :currency,
      history: [{ x: "Aug 1", y: 16_000 }, { x: "Aug 2", y: 18_450 }],
      updated_at: "Updated 1 second ago"
    )

    assert_includes html, "railsui-metric-card"
    assert_includes html, "MRR"
    assert_includes html, "$18,450.00"
    assert_includes html, "$17,200.00 previous period"
    # 18450 / 17200 - 1 == 7.27%
    assert_includes html, "+7.27%"
    assert_includes html, "Updated 1 second ago"
  end

  def test_metric_card_can_expand_into_a_larger_view
    html = railsui_metric_card(
      label: "MRR", value: 18_450, previous: 17_200, format: :currency,
      history: [{ x: "Aug 1", y: 16_000 }, { x: "Aug 2", y: 18_450 }],
      expand: true
    )

    assert_includes html, "railsui-metric-dialog"
    assert_includes html, "railsui-metric-dialog#open"
    assert_includes html, "cancel-&gt;railsui-metric-dialog#cancel"
    assert_includes html, "railsui-metric-dialog__close-icon"
    refute_includes html, "&times;"
    # A button, not a link — it goes nowhere.
    assert_includes html, "<button"
    assert_includes html, "&quot;height&quot;:420"
    assert_includes html, "&quot;right&quot;:48"
  end

  def test_expanding_needs_something_to_expand
    html = railsui_metric_card(label: "MRR", value: 0, history: [], expand: true)

    refute_includes html, "railsui-metric-dialog"
  end

  def test_metric_card_colours_delta_by_meaning_not_sign
    html = railsui_metric_card(label: "Churn", value: 2.4, previous: 2.8, format: :percentage, positive_is_good: false)

    # Churn fell, so the negative number is the good outcome.
    assert_includes html, "railsui-metric-delta--positive"
  end

  def test_the_chart_reserves_its_height_before_it_draws
    # Charts draw on scroll, so the space has to be held from the start or the
    # page grows under the reader.
    assert_includes railsui_chart([1, 2, 3], type: :line, height: 340), "min-height: 340px"
  end

  def test_reserved_height_falls_back_to_the_configured_default
    assert_includes railsui_chart([1, 2, 3], type: :line), "min-height: #{RailsuiCharts.config.default_height}px"
  end

  def test_a_labelled_point_reads_as_its_value_alone
    RailsuiCharts.config.register_type(:treemap, points: :labelled)

    html = railsui_chart([{ name: "Spend", data: [{ x: "Payroll", y: 48 }] }], type: :treemap)

    # The label is already the row heading; repeating it turns the value cell
    # into "Payroll, 48" for anyone listening.
    assert_includes html, "<td>Payroll</td><td>48</td>"
  ensure
    RailsuiCharts.config.labelled_point_types.delete(:treemap)
    RailsuiCharts.config.extra_types.delete(:treemap)
  end

  def test_a_bubble_still_reads_all_three_numbers
    html = railsui_chart([{ name: "Segments", data: [{ x: 5, y: 10, z: 20 }] }], type: :bubble)

    assert_includes html, "5, 10, 20"
  end
end
