# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "active_support"
require "active_support/testing/assertions"
require "action_view"
require "railsui_charts"

class Minitest::Test
  include ActiveSupport::Testing::Assertions
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  include RailsuiCharts::ChartHelper
  include RailsuiCharts::MetricHelper
end
