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
      RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :heatmap)
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
    assert_equal "62%", config[:plotOptions][:pie][:donut][:size]
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
    # A 2px ring in the surface colour, so overlapping dots stay legible.
    assert_equal 2, config[:markers][:strokeWidth]
  end

  def test_numeric_axes_omit_categories
    # Apex plots nothing at all when a categories array is handed to a numeric
    # axis alongside [x, y] pair data.
    %i[scatter bubble].each do |type|
      data = [{ x: 1, y: 2, z: 3 }, { x: 4, y: 5, z: 6 }]
      config = RailsuiCharts::ApexOptionsBuilder.new(data, type: type).build

      refute config[:xaxis].key?(:categories), "#{type} should not send categories to a numeric axis"
    end
  end

  def test_builds_bubble_chart_options
    data = [{ x: 1, y: 2, z: 10 }, { x: 3, y: 4, z: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :bubble)
    config = builder.build

    assert_equal "bubble", config[:chart][:type]
    assert_equal [{ x: 1, y: 2, z: 10 }, { x: 3, y: 4, z: 20 }], config[:series].first[:data]
    assert_equal "numeric", config[:xaxis][:type]
    assert_equal false, config[:stroke][:show]
  end

  def test_builds_radar_chart_options
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }, { x: "C", y: 30 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :radar)
    config = builder.build

    assert_equal "radar", config[:chart][:type]
    assert_equal [10, 20, 30], config[:series].first[:data]
    assert_equal ["A", "B", "C"], config[:xaxis][:categories]
    # The radar's polygons are its grid; the cartesian one would rule lines
    # straight through the shape.
    assert_equal false, config[:grid][:show]
    assert_equal 0, config[:markers][:strokeWidth]
  end

  def test_circular_legends_reserve_their_own_band
    # Apex's own estimate for a bottom legend runs short, and the canvas clips:
    # the last row lost its descenders, or vanished once a narrow card wrapped
    # the legend onto a second line.
    %i[pie donut polar_area].each do |type|
      config = RailsuiCharts::ApexOptionsBuilder.new([{ x: "A", y: 1 }, { x: "B", y: 2 }], type: type).build

      assert_equal RailsuiCharts::ApexOptionsBuilder::CIRCULAR_LEGEND_HEIGHT, config[:legend][:height], "#{type} should reserve a legend band"
    end
  end

  def test_builds_polar_area_chart_options
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :polar_area)
    config = builder.build

    assert_equal "polarArea", config[:chart][:type]
    assert_equal [10, 20], config[:series]
    assert_equal ["A", "B"], config[:labels]
    assert_equal false, config[:dataLabels][:enabled]
  end

  def test_uses_css_variables_for_colors
    data = [1, 2, 3]
    builder = RailsuiCharts::ApexOptionsBuilder.new(data, type: :line)
    config = builder.build

    assert_equal ["var(--rui-chart-primary, #4f46e5)"], config[:colors]
    assert_equal "var(--rui-chart-grid, rgba(148, 163, 184, 0.2))", config[:grid][:borderColor]
  end

  def test_charts_give_way_at_phone_widths
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :line, height: 340).build
    mobile = config[:responsive].first

    assert_equal 640, mobile[:breakpoint]
    # Shorter, fewer gridlines, smaller type.
    assert_equal 260, mobile[:options][:chart][:height]
    assert_equal 4, mobile[:options][:yaxis][:tickAmount]
  end

  def test_mobile_overrides_carry_decisions_already_made
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2], type: :line, axis: :right).build
    mobile = config[:responsive].first[:options]

    # Apex swaps the axis object in wholesale at a breakpoint, so a scale that
    # hangs on the right would silently jump back to the left on a phone.
    assert_equal true, mobile[:yaxis][:opposite]
    assert_equal 4, mobile[:yaxis][:tickAmount]
  end

  def test_mobile_leaves_computed_numeric_bounds_alone
    data = [{ x: 10, y: 20, z: 1 }, { x: 60, y: 55, z: 9 }]
    config = RailsuiCharts::ApexOptionsBuilder.new(data, type: :bubble).build
    mobile = config[:responsive].first[:options]

    # A numeric axis keeps the tick count that puts its labels on round
    # numbers. Forcing four over 10..70 would read 10 / 25 / 40 / 55 / 70.
    assert_equal config[:yaxis][:tickAmount], mobile[:yaxis][:tickAmount]
    refute_equal 4, mobile[:yaxis][:tickAmount]
  end

  def test_mobile_overrides_keep_hidden_axis_labels_hidden
    config = RailsuiCharts::ApexOptionsBuilder.new([{ x: "Jan", y: 1 }], type: :line, xaxis: { labels: { show: false } }).build

    assert_equal false, config[:responsive].first[:options][:xaxis][:labels][:show]
  end

  def test_a_short_chart_is_not_made_taller_on_mobile
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :line, height: 160).build

    assert_equal 160, config[:responsive].first[:options][:chart][:height]
  end

  def test_sparklines_skip_responsive_rules
    # A sparkline has no chrome to give up, so it ships no breakpoint at all.
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :sparkline).build

    refute config.key?(:responsive)
  end

  def test_gridlines_are_solid_hairlines
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :line).build

    # Dashes read as "projection" or "threshold" when all they are is a grid.
    assert_equal 0, config[:grid][:strokeDashArray]
    assert_equal false, config[:grid][:xaxis][:lines][:show]
  end

  def test_lines_are_straight_by_default_and_overridable
    assert_equal "straight", RailsuiCharts::ApexOptionsBuilder.new([1, 2], type: :line).build[:stroke][:curve]
    assert_equal "smooth", RailsuiCharts::ApexOptionsBuilder.new([1, 2], type: :line, curve: "smooth").build[:stroke][:curve]
  end

  def test_markers_are_hidden_until_hover
    config = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :line).build

    assert_equal 0, config[:markers][:size]
    assert_equal 6, config[:markers][:hover][:size]
  end

  def test_axis_labels_are_never_rotated
    config = RailsuiCharts::ApexOptionsBuilder.new([{ x: "Jan", y: 1 }], type: :line).build

    assert_equal 0, config[:xaxis][:labels][:rotate]
    assert_equal false, config[:xaxis][:labels][:rotateAlways]
  end

  def test_bar_thickness_scales_down_with_category_count
    three = RailsuiCharts::ApexOptionsBuilder.new([1, 2, 3], type: :column).build
    many = RailsuiCharts::ApexOptionsBuilder.new((1..20).to_a, type: :column).build

    assert_equal "30%", three[:plotOptions][:bar][:columnWidth]
    assert_equal "70%", many[:plotOptions][:bar][:columnWidth]
    # Rounded data-end, square baseline.
    assert_equal "end", three[:plotOptions][:bar][:borderRadiusApplication]
  end

  def test_comparison_adds_a_dashed_previous_series
    config = RailsuiCharts::ApexOptionsBuilder.new([10, 20], type: :line, compare: [8, 16], compare_label: "Last week").build

    assert_equal 2, config[:series].length
    assert_equal "Last week", config[:series].last[:name]
    assert_equal [8, 16], config[:series].last[:data]
    # Solid current, dashed previous.
    assert_equal [0, 4], config[:stroke][:dashArray]
    assert_equal true, config[:tooltip][:shared]
  end

  def test_comparison_is_ignored_for_types_that_cannot_overlay
    config = RailsuiCharts::ApexOptionsBuilder.new([10, 20], type: :pie, compare: [8, 16]).build

    assert_equal [10, 20], config[:series]
  end

  def test_axis_can_hang_on_the_right
    assert_equal true, RailsuiCharts::ApexOptionsBuilder.new([1, 2], type: :line, axis: :right).build[:yaxis][:opposite]
    assert_equal false, RailsuiCharts::ApexOptionsBuilder.new([1, 2], type: :line).build[:yaxis][:opposite]
  end

  def test_circular_charts_use_the_validated_categorical_palette
    data = [{ x: "A", y: 10 }, { x: "B", y: 20 }, { x: "C", y: 30 }]
    config = RailsuiCharts::ApexOptionsBuilder.new(data, type: :pie).build

    # Solid hex, in slot order, never cycled — Apex resolves these before the
    # Stimulus controller can substitute CSS variables.
    assert_equal RailsuiCharts::Configuration::SERIES_FALLBACKS, config[:colors]
    assert_equal 8, config[:colors].length
  end

  def test_numeric_axes_snap_to_round_bounds
    data = [[10, 18], [35, 45]].map { |x, y| { x: x, y: y } }
    config = RailsuiCharts::ApexOptionsBuilder.new(data, type: :scatter).build

    # x spans 10..35 on a step of 5, so five intervals. Apex renders
    # `tickAmount + 2` labels on a numeric x-axis, hence 4 for 10/15/…/35.
    assert_equal 10, config[:xaxis][:min]
    assert_equal 35, config[:xaxis][:max]
    assert_equal 4, config[:xaxis][:tickAmount]
    assert_equal 0, config[:xaxis][:decimalsInFloat]

    # y spans 18..45, which rounds outward to 10..50 on a step of 10. The
    # y-axis renders `tickAmount + 1`, so 4 gives 10/20/30/40/50.
    assert_equal 10, config[:yaxis][:min]
    assert_equal 50, config[:yaxis][:max]
    assert_equal 4, config[:yaxis][:tickAmount]
  end

  def test_bubble_bounds_leave_room_for_the_edge_marks
    data = [{ x: 10, y: 20, z: 5 }, { x: 60, y: 55, z: 40 }]
    config = RailsuiCharts::ApexOptionsBuilder.new(data, type: :bubble).build

    # A bubble centred on the boundary would be sliced by the plot edge.
    assert config[:xaxis][:min] < 10
    assert config[:xaxis][:max] > 60
  end

  def test_nice_bounds_survive_a_flat_series
    config = RailsuiCharts::ApexOptionsBuilder.new([{ x: 5, y: 5 }, { x: 5, y: 5 }], type: :scatter).build

    refute config[:xaxis].key?(:min)
    assert_equal 5, config[:xaxis][:tickAmount]
  end

  def test_a_registered_type_can_keep_its_labels_in_the_data
    RailsuiCharts.config.register_type(:treemap, points: :labelled)

    config = RailsuiCharts::ApexOptionsBuilder.new(
      [{ name: "Spend", data: [{ x: "Payroll", y: 48 }, { x: "Hosting", y: 12 }] }],
      type: :treemap
    ).build

    # Flattening these to [48, 12] and moving the names onto the axis loses
    # them entirely — a treemap prints its labels inside the rectangles.
    assert_equal [{ x: "Payroll", y: 48 }, { x: "Hosting", y: 12 }], config[:series].first[:data]
  ensure
    RailsuiCharts.config.labelled_point_types.delete(:treemap)
    RailsuiCharts.config.extra_types.delete(:treemap)
  end

  def test_registering_a_type_leaves_ordinary_ones_flattened
    RailsuiCharts.config.register_type(:sankey)

    config = RailsuiCharts::ApexOptionsBuilder.new(
      [{ name: "Spend", data: [{ x: "Payroll", y: 48 }] }],
      type: :sankey
    ).build

    assert_equal [48], config[:series].first[:data]
  ensure
    RailsuiCharts.config.extra_types.delete(:sankey)
  end
end
