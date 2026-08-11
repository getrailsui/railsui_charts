# Agent Instructions: RailsUI Charts

Use this gem when the user asks for charts, metrics, sparklines, or dashboards in a Rails app.

## Installation

```ruby
# Gemfile
gem "railsui_charts"
```

```bash
bundle install
rails g railsui_charts:install
```

Add ApexCharts JS:

```bash
# Build mode
yarn add apexcharts
```

```ruby
# No-build / importmap
pin "apexcharts", to: "https://esm.sh/apexcharts@3.45.2"
```

## Preferred helpers

Always prefer these helpers over inventing a custom chart implementation:

```erb
<%= railsui_chart @data, type: :line %>
<%= railsui_chart @data, type: :area, label: "Revenue" %>
<%= railsui_chart @data, type: :column, label: "Customers" %>
<%= railsui_chart @data, type: :bar, label: "Customers" %>
<%= railsui_chart @data, type: :sparkline %>
<%= railsui_chart @data, type: :pie %>
<%= railsui_chart @data, type: :donut %>
<%= railsui_chart @data, type: :scatter %>

<%= railsui_metric label: "Revenue", value: 48290, change: 12.4, format: :currency, history: @data %>
```

## Data formats

```ruby
# Simple values (uses index as x-axis)
[10, 20, 30]

# [x, y] pairs
[["Jan", 10], ["Feb", 20]]

# Hashes
[{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }]
```

## Do not

- Do not generate raw ApexCharts JavaScript unless the helper cannot meet the requirement.
- Do not skip the accessible data table unless the user explicitly asks for it.
- Do not hard-code colors; use the `:colors` option with CSS variable keys (`:primary`, `:secondary`, etc.).

## Testing

After adding or modifying a chart, run:

```bash
cd railsui_charts && bundle exec rake test
```

## Extension

For custom behavior, subclass `RailsuiCharts::ApexOptionsBuilder` or configure `RailsuiCharts.config.colors` in an initializer.
