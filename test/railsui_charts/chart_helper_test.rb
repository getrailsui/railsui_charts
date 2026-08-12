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
    # A button, not a link — it goes nowhere.
    assert_includes html, "<button"
    assert_includes html, "&quot;height&quot;:420"
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
end
