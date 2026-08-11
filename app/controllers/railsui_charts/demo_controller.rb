# frozen_string_literal: true

module RailsuiCharts
  class DemoController < ::ActionController::Base
    layout false

    def index
      @monthly_revenue = [
        { x: "Jan", y: 32_000 },
        { x: "Feb", y: 35_000 },
        { x: "Mar", y: 42_000 },
        { x: "Apr", y: 38_000 },
        { x: "May", y: 48_290 },
        { x: "Jun", y: 52_000 }
      ]

      @daily_signups = [12, 19, 15, 25, 22, 30, 28]
      @plan_distribution = [
        { x: "Starter", y: 120 },
        { x: "Pro", y: 85 },
        { x: "Enterprise", y: 32 }
      ]

      @page_views = [120, 132, 101, 134, 190, 230, 210, 180, 250, 280]
    end
  end
end
