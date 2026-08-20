# frozen_string_literal: true

require "test_helper"

class RangeBarTest < Minitest::Test
  FROM = Time.utc(2026, 8, 10, 9, 0)
  TO = Time.utc(2026, 8, 10, 11, 30)

  def build(data, **options)
    RailsuiCharts::ApexOptionsBuilder.new(data, type: :range_bar, **options).build
  end

  def test_range_bar_is_a_supported_type
    # It used to raise, which is why a timeline was not expressible at all.
    assert_includes RailsuiCharts::ApexOptionsBuilder::SUPPORTED_TYPES, :range_bar
  end

  def test_it_maps_to_the_apex_name
    assert_equal "rangeBar", build([{ x: "API", from: FROM, to: TO }]).dig(:chart, :type)
  end

  def test_from_and_to_become_the_pair_apex_wants
    # `from:`/`to:` reads better at the call site than a bare two-element array.
    point = build([{ x: "API", from: FROM, to: TO }])[:series].first[:data].first

    assert_equal "API", point[:x]
    assert_equal [FROM.to_i * 1000, TO.to_i * 1000], point[:y]
  end

  def test_a_two_element_y_works_just_as_well
    point = build([{ x: "API", y: [FROM, TO] }])[:series].first[:data].first

    assert_equal [FROM.to_i * 1000, TO.to_i * 1000], point[:y]
  end

  def test_both_ends_stay_in_the_point
    # A range read off an axis is only half a range.
    point = build([{ x: "API", from: FROM, to: TO }])[:series].first[:data].first

    assert_equal 2, point[:y].length
  end

  def test_point_metadata_survives_for_the_tooltip
    point = build([{ x: "api", name: "API recovery", meta: { kind: "deploy" }, from: FROM, to: TO }])[:series].first[:data].first

    assert_equal "api", point[:x]
    assert_equal "API recovery", point[:name]
    assert_equal({ kind: "deploy" }, point[:meta])
  end

  def test_a_plain_number_range_is_left_alone
    # Not every range is about time.
    point = build([{ x: "Band", y: [10, 40] }])[:series].first[:data].first

    assert_equal [10, 40], point[:y]
  end

  def test_it_reads_left_to_right
    assert build([{ x: "API", from: FROM, to: TO }]).dig(:plotOptions, :bar, :horizontal)
  end

  def test_the_rows_get_no_gridlines_of_their_own
    # The bar already spans its dates; a line behind every row draws the
    # categories twice.
    config = build([{ x: "API", from: FROM, to: TO }])

    refute config.dig(:grid, :yaxis, :lines, :show)
    assert config.dig(:grid, :xaxis, :lines, :show)
  end

  def test_two_spans_on_one_label_share_a_lane
    # Apex draws both in the first matching lane either way, but left to derive
    # the category list itself it also reserves a second, empty lane and gives
    # it the same name.
    config = build([
      { x: "api", from: FROM, to: TO },
      { x: "api", from: TO, to: TO + 3600 },
      { x: "web", from: FROM, to: TO }
    ])

    assert_equal %w[api web], config.dig(:xaxis, :categories)
    assert_equal 3, config[:series].first[:data].length
  end

  def test_the_accessibility_table_carries_both_ends
    html = RangeBarHelperTest.new(:test).render_range

    assert_includes html, "API"
    assert_includes html, "table"
  end
end

class RangeBarHelperTest < Minitest::Test
  def render_range
    railsui_chart([{ x: "API", from: Time.utc(2026, 8, 10), to: Time.utc(2026, 8, 11) }], type: :range_bar)
  end

  def test_it_renders_through_the_ordinary_helper
    assert_includes render_range, 'data-controller="railsui-chart"'
  end
end
