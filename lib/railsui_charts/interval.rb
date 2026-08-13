# frozen_string_literal: true

module RailsuiCharts
  # Date arithmetic for the supported bucket sizes: truncating a value to the
  # bucket it belongs in, stepping between buckets, and finding the window
  # before a window.
  #
  # This is plumbing rather than product. Filters needs it to resolve a preset
  # into a range, so it stays here even though the bucketing that builds on it
  # lives in Rails UI Charts Pro.
  module Interval
    SUPPORTED = %i[hour day week month].freeze

    class << self
      def validate!(interval)
        interval = interval.to_sym
        raise ArgumentError, "Unsupported interval: #{interval}. Supported: #{SUPPORTED.join(', ')}" unless SUPPORTED.include?(interval)

        interval
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

      # The equal-length window immediately before this one.
      def preceding(range, interval: :day)
        return if range.nil?

        length = count(range, interval)
        finish = step_back(range.first, interval)
        start = length.pred.times.inject(finish) { |value, _| step_back(value, interval) }

        start..finish
      end

      def count(range, interval)
        total = 0
        cursor = range.first

        while cursor <= range.last
          total += 1
          cursor = step_forward(cursor, interval)
        end

        total
      end

      def step_forward(value, interval)
        shift(value, interval, 1)
      end

      def step_back(value, interval)
        shift(value, interval, -1)
      end

      # Every bucket start between the two ends, inclusive.
      def each(range, interval)
        return enum_for(:each, range, interval) unless block_given?

        cursor = truncate(range.first, interval)
        finish = truncate(range.last, interval)

        while cursor <= finish
          yield cursor
          cursor = step_forward(cursor, interval)
        end
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
  end
end
