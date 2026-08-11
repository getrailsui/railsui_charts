# Rails UI Charts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Production-ready chart components for Rails. Built on [ApexCharts](https://apexcharts.com), wrapped in Rails-native helpers, and designed for Tailwind CSS.

**Live demo:** [railsui.com/charts](https://railsui.com/charts)

**Preview everything locally:** the live demo above renders every supported chart type. To see them in your own app after installing, drop this into any view:

```erb
<%= railsui_chart [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }], type: :line %>
<%= railsui_chart [{ x: "A", y: 30 }, { x: "B", y: 50 }], type: :bar %>
<%= railsui_chart [{ x: "A", y: 30 }, { x: "B", y: 50 }], type: :pie %>
```

Or clone the [railsui.com site](https://github.com/justalever/railsui_app) and visit `/charts` for the full showcase.

## Why Rails UI Charts?

AI can generate a first-draft chart in seconds. The hard part is the last 20%: accessibility, responsive behavior, dark mode, Turbo lifecycle support, loading and empty states, and a stable API that does not break when you upgrade.

Rails UI Charts gives you that polish as a drop-in Rails component.

- **Rails-native** — plain ERB helpers, Stimulus controllers, no React required
- **Accessible** — every chart renders a screen-reader-friendly data table
- **Tailwind-themed** — colors controlled by CSS variables
- **Turbo-ready** — charts initialize and destroy correctly inside Turbo Frames and Streams
- **AI-friendly** — clear API and documented conventions so coding assistants use the canonical component instead of inventing their own

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

The generator adds the CSS import and copies the Stimulus controller. You still need ApexCharts in your JavaScript:

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

All charts use the same `railsui_chart` helper. Change the `type:` to switch chart kinds.

### Line chart

```erb
<%= railsui_chart @daily_signups, type: :line %>
```

### Area chart

```erb
<%= railsui_chart @monthly_revenue,
      type: :area,
      label: "Revenue",
      format: :currency %>
```

### Column chart

```erb
<%= railsui_chart @plans,
      type: :column,
      label: "Customers" %>
```

### Horizontal bar chart

```erb
<%= railsui_chart @plans,
      type: :bar,
      label: "Customers" %>
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

### Bubble chart

```erb
<%= railsui_chart @market_segments,
      type: :bubble,
      label: "Segments" %>
```

Data points accept an optional `:z` value for bubble size:

```ruby
[{ x: 10, y: 20, z: 15 }, { x: 25, y: 35, z: 30 }]
```

### Radar chart

```erb
<%= railsui_chart @feature_scores, type: :radar, label: "Score" %>
```

### Polar area chart

```erb
<%= railsui_chart @traffic_sources, type: :polar_area %>
```

### Sparkline

```erb
<%= railsui_chart @page_views, type: :sparkline %>
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

## Supported chart types

| Type | Description |
|------|-------------|
| `:line` | Smooth line chart |
| `:area` | Gradient-filled area chart |
| `:bar` | Horizontal bar chart |
| `:column` | Vertical column chart |
| `:pie` | Pie chart with legend |
| `:donut` | Donut chart with legend |
| `:scatter` | X/Y scatter plot |
| `:bubble` | Bubble chart with size-encoded values |
| `:radar` | Radar / spider chart |
| `:polar_area` | Polar area chart |
| `:sparkline` | Tiny line chart for metric cards |

## Data formats

Charts accept an array of values, arrays of `[x, y]`, or hashes with `:x` and `:y` keys:

```ruby
railsui_chart [10, 20, 30]
railsui_chart [["Jan", 10], ["Feb", 20]]
railsui_chart [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }]
```

## Formatting

Format y-axis labels and tooltips with the `format:` option:

```erb
<%= railsui_chart @monthly_revenue, type: :area, format: :currency %>
<%= railsui_chart @growth, type: :line, format: :percentage %>
<%= railsui_chart @page_views, type: :line, format: :human %>
```

Supported formats: `:currency`, `:percentage`, `:human`, and `:number` (default). Currency uses the configured currency symbol (`$` by default).

## Styling

Colors are controlled by CSS variables. Override them in your Tailwind CSS or custom stylesheet:

```css
:root {
  --rui-chart-primary: #6366f1;
  --rui-chart-secondary: #0ea5e9;
  --rui-chart-accent: #10b981;
  --rui-chart-muted: #94a3b8;
  --rui-chart-grid: rgba(148, 163, 184, 0.18);
  --rui-chart-text: #64748b;
  --rui-chart-metric-label: #6b7280;
  --rui-chart-metric-value: #111827;
}
```

Dark mode is automatically detected via `prefers-color-scheme` or a `data-theme="dark"` attribute on the document element.

## Accessibility

Every chart renders a visually hidden table with the underlying data for screen readers. Disable it with `accessible: false` if you provide your own alternative.

## Turbo support

The Stimulus controller initializes charts on `connect` and destroys them on `disconnect`, so charts work inside Turbo Frames and Turbo Streams without leaks.

## Full access

A Rails UI membership extends the open-source gem with:

- Funnel and cohort charts
- Reporting and export tools (CSV, PDF)
- Dashboard compositions and implementation recipes
- Commercial visual presets
- Priority support and upgrade guidance

[Learn more and get full access](https://railsui.com/pricing)

## License

MIT
