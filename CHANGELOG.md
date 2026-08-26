# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org). While the version is below 1.0 the
public API may change between minor versions.

## [Unreleased]

### Fixed

- The installer no longer writes a stylesheet import that cannot resolve. From
  0.1.0 through 0.2.2 it appended `@import "../../stylesheets/railsui_charts";`
  to `app/assets/tailwind/application.css`. Relative to that file the path names
  `app/stylesheets` — not the application's own `app/assets/stylesheets`, and not
  the gem's copy, which lives outside the application where no relative path can
  reach it. Tailwind does not quietly skip an import it cannot resolve; it fails
  the build. So an application that ran the installer and used Tailwind did not
  get unstyled charts, it got no stylesheet build at all, and one that did not
  use Tailwind never received the CSS by any route.

  The stylesheet is now served from the gem through the asset pipeline, which
  already carried it, and the installer links it in the application layout.
  Nothing is copied, so `bundle update` moves the CSS the way it already moves
  the Ruby and the JavaScript. Running `rails g railsui_charts:install` again
  takes the old import back out.

- Chart data tables are hidden by the gem's own `.railsui-chart-data-table`
  rather than by the host application's `sr-only`. An application not running
  Tailwind has no such class, and rendered the table at full size in the middle
  of the page. Even where it exists it does not hide a table: `width: 1px` is a
  suggestion a table box ignores, because CSS never sizes one below its
  min-content width. The table laid out at full width and, being positioned,
  pushed the page's scroll width past the viewport — which on a phone reads as
  the whole page sliding sideways. `table-layout: fixed` is what makes the width
  stick. `sr-only` rides along for applications that already style it.

### Added

- `@getrailsui/charts/styles.css`, for an application that would rather pull the
  stylesheet into its own Tailwind build than link it separately.

## [0.2.2]

### Added

- `accessible_table:` on `railsui_chart`, for charts whose series are not the
  numbers a reader wants. A caller passes `{ headers:, rows: }` and it replaces
  the table derived from the series. The CSV export in Rails UI Charts Pro is
  built from that table, so it is corrected by the same option. This is what
  lets a waterfall describe itself as movement rather than as the invisible
  plinth it stacks to get the shape drawn.

### Fixed

- Series that do not share an x-axis now align to the union of their labels, or
  to an explicit `categories:` when one is given, since series order is not
  always reading order. Categories were read off the first series alone and
  every later series was flattened to bare values from position zero, so a
  projection labelled November landed on January, on top of the history it was
  meant to continue. Apex draws the resulting gaps as gaps.
- A complex combo keeps a `categories:` it was given. Derived lists are still
  stripped, because one alongside numeric pair data makes Apex plot nothing, but
  Apex reads `xaxis.categories` ahead of everything else and without one sets the
  axis from the first series alone. For a forecast that was ruinous: the band is
  drawn first so it sits behind the lines, so the projection's months became the
  whole axis and the earlier history disappeared.

## [0.2.1]

### Fixed

- Sparkline charts now use the Rails UI tooltip renderer, so hovered points show
  their label and formatted value instead of an empty tooltip.
- Range-bar and labelled-point tooltips now read the hovered point from the
  chart config, so timelines and treemaps show the right title, value, and
  distributed color.
- Range-bar points keep their `name` and `meta` payloads for tooltip consumers.
- Chart loading skeletons now follow the same treatment as metric cards: they
  reserve the footprint, show lightweight skeleton bars, and leave the plot area
  empty until real data arrives. They align left by default and accept
  `align: :center` or `align: :right` when a layout needs it.

## [0.2.0]

The JavaScript now comes from the gem instead of being copied into the
application. This is a breaking change to how it is installed; the helpers, the
chart API and the CSS are untouched.

### Added

- An npm package, `@getrailsui/charts`, for applications that bundle their
  JavaScript. It carries the Stimulus controllers and a
  `registerRailsuiCharts(application)` helper that registers each one under the
  identifier the Ruby helpers emit.
- Importmap support. The engine adds its own pins to the host application's
  importmap and serves a prebuilt, self-contained build, so an importmap app
  needs no package and no copied files. Both worlds use the same import line.
- `@hotwired/stimulus` and `apexcharts` are declared as peer dependencies rather
  than bundled, so an application keeps one copy of each.

### Changed

- **`rails g railsui_charts:install` no longer copies the controllers.** It adds
  the stylesheet import and prints the right next step for a bundled or an
  importmap app.
- The install generator writes through its own file actions rather than
  `Rails.root`, so it respects `destination_root` — which is also what made the
  generators testable.

### Removed

- The duplicate controllers under `lib/generators/.../templates`. They had to be
  kept in sync with the engine's own copies by hand, and had already drifted.

### Upgrading

Delete the copied controllers from `app/javascript/controllers` and follow the
README. Left in place they register the same identifiers a second time, and
Stimulus keeps the last one without complaint.

This is why it changed: a copy is frozen at the version that installed it.
`bundle update` moved the Ruby and left the JavaScript alone, so 0.1.2's fix for
empty tooltips on pie, donut and polar area charts reached nobody who did not
also know to re-copy a file nothing told them about.

## [0.1.2]

### Fixed

- Tooltips on pie, donut and polar area charts rendered as an empty box. A
  circular chart hands the tooltip a flat array of numbers and names the
  hovered slice with `seriesIndex`; reading it as one array per series gave
  every value `undefined`, and rows without a value are dropped. The slice now
  shows its name and its formatted value.

## [0.1.1]

### Fixed

- Legend markers now start where the rest of the card does. A left-aligned
  legend is inset by ApexCharts' own chrome and padding before the first item's
  margin applies, so the markers sat 28px right of the axis labels and the
  heading above them. The correction is measured against a rendered chart
  rather than derived, and the mobile breakpoint — which uses a tighter gap
  between items — is corrected to match.

## [0.1.0]

First release.

### Charts

- `railsui_chart` renders line, area, bar, column, sparkline, pie, donut,
  scatter, bubble, radar, polar area, and range bar charts from a hash, an
  array, or a set of named series
- Combo charts, where each series names its own type, and a second y-axis for
  series measured in different units
- Range bars take `from:`/`to:` pairs, so a timeline is expressible without
  arithmetic in the view

### Metrics and layout

- `railsui_metric_card` for a single value with an optional delta and sparkline
- `railsui_small_multiples` for one shape repeated across several series
- Filter rows that read and write query parameters, with interval bucketing
  handled by `RailsuiCharts::Interval`

### States

- Empty, loading, and error states for every chart type, so a view does not have
  to decide what to render when a query comes back with nothing

### Theming

- Every colour, type size, and piece of geometry is a CSS custom property or a
  Ruby setting, so charts follow the host application's palette, including dark
  mode
- The categorical palette is validated against colour-vision deficiency, a
  chroma floor, and a 3:1 contrast requirement in both light and dark

### Accessibility

- Every chart ships a visually hidden data table alongside it, so no value is
  reachable only by hovering a mark
- Animation stops when the reader has asked for reduced motion

[Unreleased]: https://github.com/getrailsui/railsui_charts/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/getrailsui/railsui_charts/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/getrailsui/railsui_charts/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/getrailsui/railsui_charts/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/getrailsui/railsui_charts/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/getrailsui/railsui_charts/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/getrailsui/railsui_charts/releases/tag/v0.1.0
