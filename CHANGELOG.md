# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org). While the version is below 1.0 the
public API may change between minor versions.

## [Unreleased]

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

[Unreleased]: https://github.com/getrailsui/railsui_charts/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/getrailsui/railsui_charts/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/getrailsui/railsui_charts/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/getrailsui/railsui_charts/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/getrailsui/railsui_charts/releases/tag/v0.1.0
