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

### Comparing against a previous period

Pass `compare:` a second series and it rides underneath the first as a dashed,
muted line on the **same axis** — never a second y-scale.

```erb
<%= railsui_chart @this_year,
      type: :area,
      label: "This year",
      compare: @last_year,
      compare_label: "Last year",
      format: :short_currency %>
```

Supported for `:line`, `:area`, `:column`, and `:sparkline`.

### Metric

A compact label / value / delta stack with an optional sparkline.

```erb
<%= railsui_metric
      label: "Monthly revenue",
      value: 48_290,
      change: 12.4,
      format: :currency,
      history: @monthly_revenue %>
```

### Metric card

The full dashboard card: label, value, delta, previous-period line, comparison
chart, and footer. The delta is computed from `value` and `previous`.

```erb
<%= railsui_metric_card
      label: "MRR",
      value: 18_450,
      previous: 17_200,
      format: :currency,
      history: @mrr_this_period,
      compare: @mrr_last_period,
      updated_at: "Updated 1 second ago",
      details_path: dashboard_path %>
```

Direction and *goodness* are separate. A falling churn rate is a win, so pass
`positive_is_good: false` and the negative delta reads green:

```erb
<%= railsui_metric_card label: "Churn rate", value: 2.4, previous: 2.8,
      format: :percentage, positive_is_good: false, history: @churn %>
```

## Time series data

`GROUP BY date` only returns rows that exist. A quiet Sunday disappears entirely and the line joins Saturday straight to Monday — a chart that looks fine and is wrong. `TimeSeries` emits every bucket in the range whether the data has it or not.

```ruby
series = RailsuiCharts::TimeSeries.new(
  Signup.group("DATE(created_at)").count,
  interval: :day,
  range: 6.days.ago.to_date..Date.current
)

series.to_a    # => [{ x: "Aug 6", y: 12 }, { x: "Aug 7", y: 0 }, ...]
series.total   # => 84
```

```erb
<%= railsui_chart series, type: :area, format: :short_currency %>
```

Takes anything keyed by a date or time — Groupdate output, a plain `group(...).count`, or a Hash you built yourself. Keys are bucketed in `Time.zone`, and rows that collapse into one bucket are summed rather than overwriting each other. Intervals: `:hour`, `:day`, `:week`, `:month`.

Pass `fill: nil` to leave real gaps in the line instead of zeroes.

`TimeSeries.count(timestamps, interval: :day)` buckets raw timestamps. It's handy for small sets, but at scale group in SQL and hand the resulting Hash to `.new` rather than loading every row.

### Level metrics and flow metrics

`series.values.last` and `series.total` are not interchangeable. A **level** — MRR, active subscribers, a churn rate — reads its latest bucket. A **flow** — new trials, volume, signups — sums the window. Summing a level is meaningless, and taking the last bucket of a flow reports one day as if it were the whole period.

## Filters

Filters belong in one row above the charts, never inside a chart card — a per-card date picker invites two cards to disagree about what "this week" means.

```ruby
def dashboard
  @filters = RailsuiCharts::Filters.new(params)
  @signups = RailsuiCharts::TimeSeries.new(
    Signup.group("DATE(created_at)").count,
    interval: @filters.interval,
    range: @filters.range
  )
end
```

```erb
<%= turbo_frame_tag "dashboard" do %>
  <%= railsui_chart_filters @filters, url: dashboard_path, frame: "dashboard" %>
  <%= railsui_metric_card label: "Signups", value: @signups.total, history: @signups.to_a %>
<% end %>
```

It submits as a plain GET form, so every slice is a shareable URL and the page still works with JavaScript off. With Turbo, only the frame re-renders.

`Filters` resolves the window and refuses combinations that do not read — hourly buckets across twelve months is 8,760 points nobody can look at, so it falls back to the preset's own interval.

| Method | Returns |
|---|---|
| `range` | the selected date range |
| `interval` | `:hour`, `:day`, `:week`, or `:month` |
| `compare?` | whether a comparison was requested |
| `previous_range` | the equal-length window immediately before, or `nil` |
| `summary` | `["Last 7 days", "Daily", "Compared to previous period"]` |

Presets: last 24 hours, 7 days, 30 days, 90 days, 12 months, and month to date.

Note that `previous_range` returns a *range*, not data — run your query again with it. Inventing the previous period's numbers is not the library's job.

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

Supported formats: `:currency`, `:short_currency`, `:percentage`, `:human`, and `:number` (default). Currency uses the configured currency symbol (`$` by default). `:short_currency` renders compact axis labels like `$19K`.

## Axis options

```erb
<%= railsui_chart @data, type: :line,
      axis: :right,        # hang the scale on the right, Stripe-style
      edge_labels: true,   # label only the first and last x tick
      curve: "smooth" %>   # default is "straight"
```

## Styling

Colors are controlled by CSS variables. Override them in your Tailwind CSS or custom stylesheet:

```css
:root {
  --rui-chart-primary: #6366f1;
  --rui-chart-muted: #94a3b8;
  --rui-chart-grid: rgba(148, 163, 184, 0.22);
  --rui-chart-text: #64748b;
  --rui-chart-surface: #ffffff;
  --rui-chart-positive: #047857;
  --rui-chart-negative: #b91c1c;
}
```

Dark mode is detected via `prefers-color-scheme`, a `dark` class, or a `data-theme="dark"` attribute on the document element, and charts re-render when it changes.

### Categorical colors

Charts that show several categories at once (pie, donut, polar area, radar, bubble) draw from eight numbered slots:

```css
:root {
  --rui-chart-series-1: #6366f1;
  --rui-chart-series-2: #ea580c;
  /* … through --rui-chart-series-8 */
}
```

Slots are assigned in order and **never cycled** — a fifth category takes slot 5, not slot 1 again.

The default order is not a style choice. It was picked by validating every ordering of these hues against the lightness band, chroma floor, colorblind separation (protanopia and deuteranopia), a normal-vision floor, and 3:1 contrast, in both light and dark. If you swap in your own brand hues, re-validate rather than assuming the guarantees carry over.

Forms where any two marks sit side by side — pie, donut, polar area, scatter, bubble — hold to a stricter all-pairs test that these hues clear for the **first four slots**. Past four categories, fold the tail into an "Other" bucket or switch to a bar chart rather than adding a ninth hue.

## States

A new account has no data, a Turbo frame spends a moment fetching, and queries time out. Each state holds the chart's footprint so nothing below it moves.

### Empty

No branching needed — `railsui_chart` renders the empty panel when the data comes back with nothing:

```erb
<%= railsui_chart @revenue, type: :area, height: 240 %>
```

Say more when it helps:

```erb
<%= railsui_chart @revenue, type: :area, height: 240,
      empty: { title: "No revenue yet",
               description: "Charges appear here once you take your first payment." } %>
```

A series of zeroes is **not** empty. A quiet day still has something to say, and a flat line at zero is how to say it.

### Loading

```erb
<%= railsui_chart_skeleton height: 240 %>
```

Render it server-side and let a Turbo Stream swap in the real chart.

On **refetch**, don't reach for the skeleton. Any element inside a container marked `aria-busy="true"` — which is what Turbo does to a frame while it loads — holds its previous render at reduced opacity instead. The numbers stay on screen and the layout stays still; a skeleton would throw the chart away and flash.

### Error

```erb
<%= railsui_chart_error height: 240,
      title: "Couldn't load revenue",
      description: "The query timed out. Try a shorter range." %>
```

A failure reads as a failure rather than as an absence, so nobody mistakes a broken query for a quiet month.

## Accessibility

Every chart renders a visually hidden table with the underlying data for screen readers, so no value is reachable only by hovering a mark. Comparison series get their own column. Disable it with `accessible: false` if you provide your own alternative.

Charts also respect `prefers-reduced-motion` and skip their entry animation.

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
