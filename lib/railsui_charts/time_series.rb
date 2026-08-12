# frozen_string_literal: true

module RailsuiCharts
  # Turns grouped time data into chart points.
  #
  # The job this does that hand-rolled code usually gets wrong is **filling the
  # gaps**. A `GROUP BY date` query only returns days that had rows, so a quiet
  # Sunday silently disappears and the line joins Saturday straight to Monday —
  # a chart that looks fine and is wrong. Every bucket in the range is emitted,
  # present in the data or not.
  #
  #   RailsuiCharts::TimeSeries.new(
  #     Signup.group_by_day(:created_at).count,
  #     interval: :day,
  #     range: 6.days.ago.to_date..Date.current
  #   ).to_a
  #   # => [{ x: "Aug 6", y: 12 }, { x: "Aug 7", y: 0 }, ...]
  #
  # Accepts anything keyed by a date or time: Groupdate output, a plain
  # `group(...).count`, or a Hash you built yourself.
  class TimeSeries
    INTERVALS = %i[hour day week month].freeze

    LABEL_FORMATS = {
      hour: "%-l%P",
      day: "%b %-d",
      week: "%b %-d",
      month: "%b %Y"
    }.freeze

    attr_reader :interval, :range

    def initialize(data, interval: :day, range: nil, fill: 0, label: nil)
      @interval = normalize_interval(interval)
      @fill = fill
      @label = label || LABEL_FORMATS.fetch(@interval)
      @buckets = bucket_data(data)
      @range = range || derived_range
    end

    def to_a
      return [] if @range.nil?

      each_bucket.map do |bucket|
        { x: bucket.strftime(@label), y: @buckets.fetch(bucket, @fill) }
      end
    end
    alias to_ary to_a

    def values
      to_a.map { |point| point[:y] }
    end

    def total
      values.compact.sum
    end

    # The equal-length window immediately before this one, so a caller can run
    # the same query again for a comparison series. The range is returned rather
    # than the data: inventing the previous period's numbers is not this
    # object's job.
    def previous_range
      preceding(@range, interval: @interval)
    end

    class << self
      # Buckets raw timestamps. Handy for small sets and for tests; at scale,
      # group in SQL and hand the resulting Hash to .new instead of loading
      # every row into memory.
      def count(timestamps, interval: :day, **options)
        grouped = Array(timestamps).compact.each_with_object(Hash.new(0)) do |timestamp, memo|
          memo[truncate(timestamp, interval)] += 1
        end

        new(grouped, interval: interval, **options)
      end

      def preceding(range, interval: :day)
        return if range.nil?

        length = bucket_count(range, interval)
        finish = step_back(range.first, interval)
        start = length.pred.times.inject(finish) { |date, _| step_back(date, interval) }

        start..finish
      end

      def truncate(value, interval)
        time = coerce(value)
        return if time.nil?

        case interval.to_sym
        when :hour then time.change(min: 0, sec: 0)
        when :week then time.to_date.beginning_of_week
        when :month then time.to_date.beginning_of_month
        else time.to_date
        end
      end

      def coerce(value)
        case value
        when Time, DateTime then in_zone(value)
        when Date then value
        when String then parse(value)
        when Numeric then in_zone(Time.at(value))
        else value.respond_to?(:to_time) ? in_zone(value.to_time) : nil
        end
      end

      def bucket_count(range, interval)
        count = 0
        cursor = range.first
        while cursor <= range.last
          count += 1
          cursor = step_forward(cursor, interval)
        end
        count
      end

      def step_forward(value, interval)
        shift(value, interval, 1)
      end

      def step_back(value, interval)
        shift(value, interval, -1)
      end

      private

      def shift(value, interval, direction)
        case interval.to_sym
        when :hour then value + (direction * 3600)
        when :week then value + (direction * 7)
        when :month then value >> direction
        else value + direction
        end
      end

      def in_zone(time)
        Time.respond_to?(:zone) && Time.zone ? time.in_time_zone : time
      end

      def parse(value)
        Time.respond_to?(:zone) && Time.zone ? Time.zone.parse(value) : Time.parse(value)
      rescue ArgumentError, TypeError
        nil
      end
    end

    private

    def normalize_interval(interval)
      interval = interval.to_sym
      raise ArgumentError, "Unsupported interval: #{interval}. Supported: #{INTERVALS.join(', ')}" unless INTERVALS.include?(interval)

      interval
    end

    def bucket_data(data)
      pairs = data.respond_to?(:to_h) ? data.to_h : Array(data)

      pairs.each_with_object({}) do |(key, value), memo|
        bucket = self.class.truncate(key, @interval)
        next if bucket.nil?

        # Two source rows can land in one bucket once the interval is coarser
        # than the data (hourly rows grouped by day).
        memo[bucket] = (memo[bucket] || 0) + value.to_f
      end
    end

    def derived_range
      return if @buckets.empty?

      keys = @buckets.keys.sort
      keys.first..keys.last
    end

    def each_bucket
      return enum_for(:each_bucket) unless block_given?

      cursor = self.class.truncate(@range.first, @interval)
      finish = self.class.truncate(@range.last, @interval)

      while cursor <= finish
        yield cursor
        cursor = self.class.step_forward(cursor, @interval)
      end
    end

    def preceding(range, interval:)
      self.class.preceding(range, interval: interval)
    end
  end
end
