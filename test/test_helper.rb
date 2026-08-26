# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "active_support"
require "active_support/testing/assertions"
require "action_view"
require "railsui_charts"

class Minitest::Test
  # ActionView's capture helper writes through this on its way in and out of a
  # block, and before 7.1 it assumed the including object had one. Without it
  # every helper that yields — which is every helper that builds a table — fails
  # on Rails 7.0 with an error that says nothing about the cause.
  attr_accessor :output_buffer

  include ActiveSupport::Testing::Assertions
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  include RailsuiCharts::ChartHelper
  include RailsuiCharts::MetricHelper
end
