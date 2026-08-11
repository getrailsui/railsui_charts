# frozen_string_literal: true

require "test_helper"

class ApexOptionsBuilderTest < Minitest::Test
  def test_builds_line_chart_options
    data = [10, 20, 30]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :line)
    config = builder.build

    assert_equal "line", config[:chart][:type]
    assert_equal [10, 20, 30], config[:series].first[:data]
    assert_equal "Value", config[:series].first[:name]
  end

  def test_builds_area_chart_options
    data = [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :area, label: "Revenue")
    config = builder.build

    assert_equal "area", config[:chart][:type]
    assert_equal ["Jan", "Feb"], config[:xaxis][:categories]
    assert_equal [10, 20], config[:series].first[:data]
    assert_equal "Revenue", config[:series].first[:name]
    assert_equal "gradient", config[:fill][:type]
  end

  def test_builds_sparkline_options
    data = [10, 20, 30, 40]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :sparkline)
    config = builder.build

    assert_equal "line", config[:chart][:type]
    assert config[:chart][:sparkline][:enabled]
    assert_equal false, config[:grid][:show]
    assert_equal false, config[:xaxis][:labels][:show]
  end

  def test_rejects_unsupported_type
    assert_raises(ArgumentError) do
      RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :pie)
    end
  end

  def test_uses_css_variables_for_colors
    data = [1, 2, 3]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :line)
    config = builder.build

    assert_equal ["var(--rui-chart-primary, #4f46e5)"], config[:colors]
    assert_equal "var(--rui-chart-grid, rgba(148, 163, 184, 0.2))", config[:grid][:borderColor]
  end
end
