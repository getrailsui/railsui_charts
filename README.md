# Rails UI Charts

[![Gem Version](https://img.shields.io/gem/v/railsui_charts.svg)](https://rubygems.org/gems/railsui_charts)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Production-ready chart components for Rails. Built on [ApexCharts](https://apexcharts.com), wrapped in Rails-native helpers, and designed for Tailwind CSS.

**Live demo:** [railsui.com/charts](https://railsui.com/charts)

**Preview everything locally:** the live demo above renders every supported chart type. To see them in your own app after installing, drop this into any view:

```erb
<%= railsui_chart [{ x: "Jan", y: 10 }, { x: "Feb", y: 20 }], type: :line %>
<%= railsui_chart [{ x: "A", y: 30 }, { x: "B", y: 50 }], type: :bar %>
<%= railsui_chart [{ x: "A", y: 30 }, { x: "B", y: 50 }], type: :pie %>
```

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

Then:

```bash
bundle install
rails g railsui_charts:install
```

The generator adds the stylesheet import. The JavaScript is served from the gem
rather than copied into your app, so `bundle update` moves all of it.

### Bundled apps (esbuild, bun, rollup, webpack)

```bash
yarn add @getrailsui/charts apexcharts
```

```js
// app/javascript/controllers/index.js
import { registerRailsuiCharts } from "@getrailsui/charts"

registerRailsuiCharts(application)
```

### Importmap

Nothing to add for the controllers — the engine pins them. ApexCharts is a peer
dependency, so pin that:

```ruby
# config/importmap.rb
pin "apexcharts", to: "https://esm.sh/apexcharts@3.45.2"
```

```js
// app/javascript/controllers/index.js
import { registerRailsuiCharts } from "@getrailsui/charts"

registerRailsuiCharts(application)
```

### Upgrading from 0.1.x

0.1.x copied the controllers into `app/javascript/controllers`. Those copies are
frozen at whatever version installed them — `bundle update` moved the Ruby and
left them alone, which is the reason this changed. Delete them and follow one of
the paths above:

```bash
rm app/javascript/controllers/railsui_chart_controller.js \
   app/javascript/controllers/railsui_chart_filters_controller.js \
   app/javascript/controllers/railsui_metric_dialog_controller.js
```

Leaving them in place registers the same identifiers twice. Stimulus keeps the
last registration and says nothing about it, so the symptom is a chart behaving
like an older version of itself.

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

### Several series

Pass an array of `{ name:, data: }` instead of a bare series. The `data` key is what tells the two apart.

```erb
<%= railsui_chart [
      { name: "Starter", data: @starter },
      { name: "Pro", data: @pro },
      { name: "Enterprise", data: @enterprise }
    ], type: :column %>
```

Each series takes the next palette slot in order, and two or more always carry a legend — colour is never the only thing telling them apart.

### Combo and dual axis

Give a series its own `type:` and the chart draws more than one shape. Give it `axis: :right` and it gets its own scale.

```erb
<%= railsui_chart [
      { name: "Revenue",    data: @revenue, type: :column, format: :short_currency },
      { name: "Churn rate", data: @churn,   type: :line, axis: :right, format: :percentage }
    ] %>
```

There is no `type: :combo` to remember — a series naming a type is what makes the chart mixed.

`format:` on a series dresses its own axis and its own row in the tooltip, so money and percentages read in their own units. Both scales are cut into the same number of intervals so their gridlines land on each other, and each is fitted to its own values. A side carrying columns reaches zero; a side carrying only lines does not, since forcing zero onto a rate hovering near 3% flattens it against the top of the plot.

Axis labels take the colour of the series they measure. With two scales, position alone does not say which belongs to which.

### Timelines and ranges

`:range_bar` plots spans rather than points. Pass `from:` and `to:` with whatever `Time` or `Date` you already have — Apex wants milliseconds, and handing it a `Time` gives "Invalid Date" rather than an error.

```erb
<%= railsui_chart [
      { x: "web", from: deploy.started_at, to: deploy.finished_at },
      { x: "api", from: incident.began_at, to: incident.resolved_at }
    ], type: :range_bar %>
```

Rows sharing a label stack onto one lane. A bare two-element `y` works too, for a range that is not about time.

### Stacking

```erb
<%= railsui_chart @plans, type: :column, stacked: true %>
<%= railsui_chart @plans, type: :column, stacked: :percent %>
```

Stacking answers "what is this made of over time", which a grouped chart cannot. `:percent` switches from totals to share. Segments separate with a 2px gap in the surface colour rather than a stroke, so the divider never reads as data.

### Small multiples

```erb
<%= railsui_small_multiples @plans, type: :area, columns: 3 %>
```

One small chart per series, **sharing a y-scale**. This is the honest answer when there are more categories than a single chart can hold: eight lines on one axis is a plate of spaghetti, and a ninth colour is not distinguishable from the others anyway. Facets scale where colour does not.

Every facet takes the same colour, because the title carries identity — spending a hue on it would say nothing extra. The shared scale is the point: left to themselves, each facet would fit its own data and a small series would look like a large one.

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

`railsui_chart` takes a grouped hash straight from the database:

```ruby
@revenue = Order.paid.where(created_at: range)
                .group("TO_CHAR(created_at, 'Mon')").sum(:total)
```

```erb
<%= railsui_chart @revenue, type: :column, format: :short_currency %>
```

Note that a `GROUP BY` only returns rows that exist, so a month with no orders
is simply absent and the axis quietly shortens. Filling those gaps —
along with bucketing, summing rows that collapse together, and labelling — is
what `RailsuiChartsPro::TimeSeries` does. See [Full access](#full-access).

## Filters

Filters belong in one row above the charts, never inside a chart card — a per-card date picker invites two cards to disagree about what "this week" means.

```ruby
def dashboard
  @filters = RailsuiCharts::Filters.new(params)
  @signups = Signup.where(created_at: @filters.range)
                   .group("TO_CHAR(created_at, 'Mon DD')").count
end
```

```erb
<%= turbo_frame_tag "dashboard" do %>
  <%= railsui_chart_filters @filters, url: dashboard_path, frame: "dashboard" %>
  <%= railsui_metric_card label: "Signups", value: @signups.values.sum, history: @signups %>
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

`previous_range` returns a *range*, not data — run your query again with it. Inventing the previous period's numbers is not the library's job.

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
| `:range_bar` | Spans on an axis: timelines, Gantt, durations |

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

Type is themed the same way. These reach ApexCharts as CSS strings, so the controller resolves them against the chart's own element — which means setting one on a card scopes it to that card's charts:

```css
:root {
  --rui-chart-font-family: inherit;
  --rui-chart-font-size: 12px;      /* axis and data labels */
  --rui-chart-font-size-sm: 11px;   /* legend, and under 640px */
  --rui-chart-text-size: 0.8125rem; /* tooltip rows, metric labels, tables */
  --rui-chart-value-size: 1.375rem; /* the metric card headline */
}
```

Geometry cannot ride that channel. ApexCharts does arithmetic on a border radius and a stroke width, and a resolved CSS variable arrives as a string — `"4" + 1` is `"41"`. Those live in an initializer:

```ruby
RailsuiCharts.configure do |config|
  config.geometry[:bar_radius] = 4
  config.geometry[:stroke_width] = 2
  config.geometry[:marker_size] = 0
  config.geometry[:marker_hover_size] = 6
end
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

## Tooltips

Charts render their own tooltip rather than Apex's. It leads with the metric and how much it moved, then lists dated rows with values right-aligned, and it draws from CSS variables so it follows the theme instead of being a dark slab on a light page.

Three options control what it says:

```erb
<%= railsui_chart @revenue, type: :line,
      tooltip_heading: :category,   # :series or :category — defaults to :series when comparing
      tooltip_delta: false,         # hide the change badge
      tooltip_style: false %>       # hand the tooltip back to Apex entirely
```

Appearance is CSS variables, so a tooltip can be restyled without touching the cards around it:

```css
:root {
  --rui-chart-tooltip-bg: #ffffff;
  --rui-chart-tooltip-text: #111827;
  --rui-chart-tooltip-muted: #6b7280;
  --rui-chart-tooltip-border: rgba(17, 24, 39, 0.14);
  --rui-chart-tooltip-radius: 0.5rem;
  --rui-chart-tooltip-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
}
```

The change badge uses `--rui-chart-positive` and `--rui-chart-negative`. Direction and goodness are separate here as they are on the card: `railsui_metric_card` passes `positive_is_good` down, so a falling churn rate reads green in the tooltip too.

Passing your own `tooltip: { custom: ... }` also takes precedence — the built-in one steps aside.

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
<%= railsui_metric_card_skeleton chart_height: 180 %>
<%= railsui_chart_skeleton height: 240, type: :donut %>
```

Render one server-side and let a Turbo Stream swap in the real thing.

The card skeleton stands in for the text that is coming and leaves the plot area empty — a slab where the chart goes claims more about the shape of the data than a loading state can know. A standalone chart skeleton keeps faint gridlines, since it has nothing else to say it is a chart, and takes the shape of its `type:`.

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

## Performance

Charts draw when they scroll into view rather than all at once on page load, so
a long dashboard does not spend its first seconds laying out charts nobody is
looking at. Each one starts 300px before it reaches the viewport, and the
helper reserves its height server-side so nothing shifts as they arrive.

Browsers without `IntersectionObserver` render immediately, as before.

## Turbo support

The Stimulus controller initializes charts on `connect` and destroys them on `disconnect`, so charts work inside Turbo Frames and Turbo Streams without leaks.

## Full access

A Rails UI membership adds `railsui_charts_pro`, which builds on this gem
rather than replacing it:

- **Time series** — `TimeSeries` fills the gaps a `GROUP BY` leaves behind, buckets to any interval, and sums rows that collapse together
- **Waterfall and funnel** — the bridging arithmetic and the ordinal ramp handled
- **Cohort and retention grids** — monthly cohorts on a single-hue ramp
- **Treemap and bar lists** — part-to-whole past the four-slot cap, and the ranked row every overview ends with
- **Annotations** — deploy markers, incident bands, and target lines
- **Live updates and export** — Turbo Stream broadcasts, and PNG and CSV download

Installed over GitHub with your existing credentials — no license key, nothing
calls home:

```ruby
gem "railsui_charts_pro", github: "getrailsui/railsui_charts_pro"
```

[Get full access](https://railsui.com/pricing)

## License

MIT
