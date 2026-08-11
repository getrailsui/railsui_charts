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
      RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :radar)
    end
  end

  def test_builds_column_chart_options
    data = [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :column)
    config = builder.build

    assert_equal "bar", config[:chart][:type]
    assert_equal false, config[:plotOptions][:bar][:horizontal]
    assert_equal [10, 20], config[:series].first[:data]
  end

  def test_builds_horizontal_bar_chart_options
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :bar)
    config = builder.build

    assert_equal "bar", config[:chart][:type]
    assert_equal true, config[:plotOptions][:bar][:horizontal]
  end

  def test_builds_pie_chart_options
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }, { x: "C", y: 30 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :pie)
    config = builder.build

    assert_equal "pie", config[:chart][:type]
    assert_equal [10, 20, 30], config[:series]
    assert_equal ["A", "B", "C"], config[:labels]
    assert_equal false, config[:grid][:show]
  end

  def test_builds_donut_chart_options
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :donut)
    config = builder.build

    assert_equal "donut", config[:chart][:type]
    assert_equal "55%", config[:plotOptions][:pie][:donut][:size]
    assert_equal false, config[:plotOptions][:pie][:donut][:labels][:show]
    assert_equal false, config[:dataLabels][:enabled]
    assert_equal "bottom", config[:legend][:position]
  end

  def test_builds_scatter_chart_options
    data = [[1, 2], [3, 4], [5, 6]]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :scatter)
    config = builder.build

    assert_equal "scatter", config[:chart][:type]
    assert_equal [[1, 2], [3, 4], [5, 6]], config[:series].first[:data]
    assert_equal "numeric", config[:xaxis][:type]
    assert_equal 6, config[:markers][:size]
    assert_equal 0, config[:markers][:strokeWidth]
  end

  def test_uses_css_variables_for_colors
    data = [1, 2, 3]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :line)
    config = builder.build

    assert_equal ["var(--rui-chart-primary, #4f46e5)"], config[:colors]
    assert_equal "var(--rui-chart-grid, rgba(148, 163, 184, 0.2))", config[:grid][:borderColor]
  end
end
