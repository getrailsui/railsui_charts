# frozen_string_literal: true

require "test_helper"

class TimeSeriesTest < Minitest::Test
  def test_fills_gaps_across_the_range
    # A GROUP BY query only returns days that had rows. Aug 2 and Aug 4 had
    # none, and dropping them would join Aug 1 straight to Aug 3.
    data = { Date.new(2026, 8, 1) => 5, Date.new(2026, 8, 3) => 9, Date.new(2026, 8, 5) => 2 }

    series = RailsuiCharts::TimeSeries.new(data, interval: :day, range: Date.new(2026, 8, 1)..Date.new(2026, 8, 5))

    assert_equal [5, 0, 9, 0, 2], series.values
    assert_equal ["Aug 1", "Aug 2", "Aug 3", "Aug 4", "Aug 5"], series.to_a.map { |p| p[:x] }
  end

  def test_fill_value_is_configurable
    data = { Date.new(2026, 8, 1) => 5 }
    series = RailsuiCharts::TimeSeries.new(data, interval: :day, range: Date.new(2026, 8, 1)..Date.new(2026, 8, 3), fill: nil)

    assert_equal [5, nil, nil], series.values
  end

  def test_derives_the_range_from_the_data_when_none_is_given
    data = { Date.new(2026, 8, 3) => 1, Date.new(2026, 8, 1) => 4 }
    series = RailsuiCharts::TimeSeries.new(data, interval: :day)

    assert_equal [4, 0, 1], series.values
  end

  def test_accepts_string_and_time_keys
    data = { "2026-08-01" => 3, Time.utc(2026, 8, 2, 13, 30) => 7 }
    series = RailsuiCharts::TimeSeries.new(data, interval: :day, range: Date.new(2026, 8, 1)..Date.new(2026, 8, 2))

    assert_equal [3, 7], series.values
  end

  def test_sums_rows_that_collapse_into_one_bucket
    # Hourly rows grouped by day must add up, not overwrite each other.
    data = { Time.utc(2026, 8, 1, 9) => 2, Time.utc(2026, 8, 1, 17) => 3 }
    series = RailsuiCharts::TimeSeries.new(data, interval: :day, range: Date.new(2026, 8, 1)..Date.new(2026, 8, 1))

    assert_equal [5], series.values
  end

  def test_counts_raw_timestamps
    timestamps = [
      Time.utc(2026, 8, 1, 4), Time.utc(2026, 8, 1, 20), Time.utc(2026, 8, 3, 9)
    ]

    series = RailsuiCharts::TimeSeries.count(timestamps, interval: :day, range: Date.new(2026, 8, 1)..Date.new(2026, 8, 3))

    assert_equal [2, 0, 1], series.values
    assert_equal 3, series.total
  end

  def test_previous_range_is_the_equal_length_window_immediately_before
    series = RailsuiCharts::TimeSeries.new({}, interval: :day, range: Date.new(2026, 8, 6)..Date.new(2026, 8, 12))

    assert_equal Date.new(2026, 7, 30)..Date.new(2026, 8, 5), series.previous_range
  end

  def test_monthly_buckets_step_by_month
    data = { Date.new(2026, 1, 15) => 4, Date.new(2026, 3, 2) => 6 }
    series = RailsuiCharts::TimeSeries.new(data, interval: :month, range: Date.new(2026, 1, 1)..Date.new(2026, 3, 31))

    assert_equal [4, 0, 6], series.values
    assert_equal ["Jan 2026", "Feb 2026", "Mar 2026"], series.to_a.map { |p| p[:x] }
  end

  def test_rejects_an_unsupported_interval
    assert_raises(ArgumentError) { RailsuiCharts::TimeSeries.new({}, interval: :fortnight) }
  end

  def test_renders_straight_into_the_chart_helper
    series = RailsuiCharts::TimeSeries.new({ Date.new(2026, 8, 1) => 5 }, interval: :day)

    assert_equal [{ x: "Aug 1", y: 5 }], series.to_a
  end
end
