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
    assert_includes html, "railsui-metric-change--positive"
  end
end
