# Rails UI Charts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Production-ready chart components for Rails. Built on [ApexCharts](https://apexcharts.com), wrapped in Rails-native helpers, and designed for Tailwind CSS.

**Live demo:** [railsui.com/charts](https://railsui.com/charts)

## Why RailsUI Charts?

AI can generate a first-draft chart in seconds. The hard part is the last 20%: accessibility, responsive behavior, dark mode, Turbo lifecycle support, loading and empty states, and a stable API that does not break when you upgrade.

RailsUI Charts gives you that polish as a drop-in Rails component.

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
      label: "Revenue" %>
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
  --rui-chart-muted: #94a3b8;
  --rui-chart-grid: rgba(148, 163, 184, 0.2);
  --rui-chart-text: #64748b;
}
```

Dark mode is automatically detected via `prefers-color-scheme` or a `data-theme="dark"` attribute on the document element.

## Accessibility

Every chart renders a visually hidden table with the underlying data for screen readers. Disable it with `accessible: false` if you provide your own alternative.

## Turbo support

The Stimulus controller initializes charts on `connect` and destroys them on `disconnect`, so charts work inside Turbo Frames and Turbo Streams without leaks.

## Pro features

RailsUI Pro extends the open-source gem with:

- Funnel and cohort charts
- Reporting and export tools (CSV, PDF)
- Dashboard compositions and implementation recipes
- Commercial visual presets
- Priority support and upgrade guidance

[Learn more about RailsUI Pro](https://railsui.com/pricing)

## License

MIT
