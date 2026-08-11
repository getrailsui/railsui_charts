# RailsUI Charts

Production-ready chart components for Rails. Built on [ApexCharts](https://apexcharts.com), wrapped in Rails-native helpers, and designed for Tailwind CSS.

## Installation

Add to your Gemfile:

```ruby
gem "railsui_charts"
```

Then run:

```bash
bundle install
rails g railsui_charts:install
```

Mount the engine in `config/routes.rb` to access the demo page:

```ruby
mount RailsuiCharts::Engine, at: "/railsui_charts"
```

The generator adds the CSS import and copies the Stimulus controller. You still need to add ApexCharts to your JavaScript setup:

**Build mode:**

```bash
yarn add apexcharts
```

**No-build (importmap):**

```ruby
# config/importmap.rb
pin "apexcharts", to: "https://esm.sh/apexcharts@3.45.2"
```

## Usage

### Line chart

```erb
<%= railsui_chart @daily_signups, type: :line %>
```

### Area chart with labels

```erb
<%= railsui_chart @monthly_revenue,
      type: :area,
      label: "Revenue",
      colors: [:primary] %>
```

### Bar chart

```erb
<%= railsui_chart @plans,
      type: :bar,
      label: "Customers" %>
```

### Sparkline

```erb
<%= railsui_chart @page_views, type: :sparkline %>
```

### Column chart

```erb
<%= railsui_chart @monthly_revenue, type: :column %>
```

### Horizontal bar chart

```erb
<%= railsui_chart @plans, type: :bar %>
```

### Pie chart

```erb
<%= railsui_chart @plan_distribution, type: :pie %>
```

### Donut chart

```erb
<%= railsui_chart @plan_distribution, type: :donut %>
```

### Scatter chart

```erb
<%= railsui_chart @experiments, type: :scatter %>
```

### Metric card

```erb
<%= railsui_metric
      label: "Monthly revenue",
      value: 48_290,
      change: 12.4,
      format: :currency,
      history: @monthly_revenue %>
```

## Data formats

Charts accept an array of values, arrays of `[x, y]`, or hashes with `:x` and `:y` keys:

```ruby
railsui_chart [10, 20, 30]
railsui_chart [["Jan", 10], ["Feb", 20]]
railsui_chart [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }]
```

## Styling

Colors are controlled by CSS variables. Override them in your Tailwind CSS or custom stylesheet:

```css
:root {
  --rui-chart-primary: #4f46e5;
  --rui-chart-secondary: #0ea5e9;
  --rui-chart-accent: #10b981;
  --rui-chart-grid: rgba(148, 163, 184, 0.2);
  --rui-chart-text: #64748b;
}
```

Dark mode is automatically detected via `prefers-color-scheme` or a `data-theme="dark"` attribute on the document element.

## Accessibility

Every chart renders a visually hidden table with the underlying data for screen readers. Disable it with `accessible: false` if you provide your own alternative.

## Turbo support

The Stimulus controller initializes charts on `connect` and destroys them on `disconnect`, so charts work inside Turbo Frames and Turbo Streams without leaks.

## License

MIT
