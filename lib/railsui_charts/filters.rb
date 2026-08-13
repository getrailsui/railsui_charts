# frozen_string_literal: true

module RailsuiCharts
  # Resolves request params into the window every chart on a page shares.
  #
  # Filters belong above the charts, not inside them: one row scopes the whole
  # view so every chart re-renders against the same slice. A per-card date
  # picker invites two cards to disagree about what "this week" means.
  #
  #   filters = RailsuiCharts::Filters.new(params)
  #   filters.range           # => Mon, 06 Aug..Mon, 12 Aug
  #   filters.interval        # => :day
  #   filters.previous_range  # => the preceding 7 days, when comparing
  class Filters
    Preset = Struct.new(:key, :label, :length, :interval, :unit, keyword_init: true)

    PRESETS = [
      Preset.new(key: "24h", label: "Last 24 hours", length: 24, interval: :hour, unit: :hour),
      Preset.new(key: "7d", label: "Last 7 days", length: 7, interval: :day, unit: :day),
      Preset.new(key: "30d", label: "Last 30 days", length: 30, interval: :day, unit: :day),
      Preset.new(key: "90d", label: "Last 90 days", length: 13, interval: :week, unit: :week),
      Preset.new(key: "12m", label: "Last 12 months", length: 12, interval: :month, unit: :month),
      Preset.new(key: "mtd", label: "Month to date", length: nil, interval: :day, unit: :day)
    ].freeze

    DEFAULT_PRESET = "7d"

    INTERVAL_LABELS = { hour: "Hourly", day: "Daily", week: "Weekly", month: "Monthly" }.freeze

    attr_reader :preset

    def initialize(params = {}, today: nil)
      params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      params = params.transform_keys(&:to_s)

      @today = today || current_date
      @preset = find_preset(params["range"])
      @interval = coerce_interval(params["interval"])
      @compare = compare_param?(params["compare"])
    end

    def range
      @range ||= @preset.key == "mtd" ? (@today.beginning_of_month..@today) : trailing_range
    end

    def interval
      @interval || @preset.interval
    end

    def compare?
      @compare
    end

    def previous_range
      return unless compare?

      Interval.preceding(range, interval: interval)
    end

    def presets
      PRESETS
    end

    def intervals
      available = case @preset.unit
                  when :hour then %i[hour day]
                  when :month then %i[month]
                  when :week then %i[week month]
                  else %i[day week month]
                  end

      available.map { |key| [INTERVAL_LABELS.fetch(key), key.to_s] }
    end

    def label
      @preset.label
    end

    def interval_label
      INTERVAL_LABELS.fetch(interval)
    end

    def summary
      parts = [label, interval_label]
      parts << "Compared to previous period" if compare?
      parts
    end

    def to_params
      { range: @preset.key, interval: interval.to_s, compare: compare? ? "1" : "0" }
    end

    private

    def trailing_range
      finish = @preset.unit == :hour ? current_time : @today
      start = (@preset.length - 1).times.inject(finish) { |value, _| Interval.step_back(value, @preset.interval) }

      start..finish
    end

    def find_preset(key)
      PRESETS.find { |preset| preset.key == key.to_s } || PRESETS.find { |preset| preset.key == DEFAULT_PRESET }
    end

    # An explicit interval only sticks if it makes sense for the window: hourly
    # buckets across twelve months is 8,760 points nobody can read.
    def coerce_interval(value)
      return if value.blank?

      candidate = value.to_sym
      allowed = intervals.map { |(_, key)| key.to_sym }
      allowed.include?(candidate) ? candidate : nil
    end

    def compare_param?(value)
      return true if value.nil?

      %w[1 true yes on].include?(value.to_s.downcase)
    end

    def current_date
      Time.respond_to?(:zone) && Time.zone ? Time.zone.today : Date.today
    end

    def current_time
      Time.respond_to?(:zone) && Time.zone ? Time.zone.now : Time.now
    end
  end
end
