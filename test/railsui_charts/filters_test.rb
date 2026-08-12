# frozen_string_literal: true

require "test_helper"

class FiltersTest < Minitest::Test
  TODAY = Date.new(2026, 8, 12)

  def filters(params = {})
    RailsuiCharts::Filters.new(params, today: TODAY)
  end

  def test_defaults_to_the_last_seven_days_compared
    subject = filters

    assert_equal "7d", subject.preset.key
    assert_equal Date.new(2026, 8, 6)..TODAY, subject.range
    assert_equal :day, subject.interval
    assert subject.compare?
  end

  def test_unknown_range_falls_back_to_the_default
    assert_equal "7d", filters("range" => "all-time").preset.key
  end

  def test_month_to_date_starts_at_the_first
    subject = filters("range" => "mtd")

    assert_equal Date.new(2026, 8, 1)..TODAY, subject.range
  end

  def test_previous_range_is_the_preceding_window
    assert_equal Date.new(2026, 7, 30)..Date.new(2026, 8, 5), filters.previous_range
  end

  def test_previous_range_is_absent_when_not_comparing
    assert_nil filters("compare" => "0").previous_range
  end

  def test_compare_accepts_checkbox_values
    assert filters("compare" => "1").compare?
    refute filters("compare" => "0").compare?
    refute filters("compare" => "false").compare?
  end

  def test_interval_can_be_overridden_within_what_the_window_supports
    assert_equal :week, filters("range" => "30d", "interval" => "week").interval
  end

  def test_nonsense_intervals_fall_back_to_the_preset_default
    # Hourly buckets across twelve months is 8,760 points nobody can read.
    subject = filters("range" => "12m", "interval" => "hour")

    assert_equal :month, subject.interval
  end

  def test_ninety_days_buckets_weekly
    subject = filters("range" => "90d")

    assert_equal :week, subject.interval
    # Thirteen weekly buckets ending today.
    assert_equal Date.new(2026, 5, 20)..TODAY, subject.range
  end

  def test_summary_reads_as_a_sentence
    assert_equal ["Last 7 days", "Daily", "Compared to previous period"], filters.summary
    assert_equal ["Last 30 days", "Daily"], filters("range" => "30d", "compare" => "0").summary
  end

  def test_round_trips_to_params
    assert_equal({ range: "30d", interval: "week", compare: "0" },
                 filters("range" => "30d", "interval" => "week", "compare" => "0").to_params)
  end
end
