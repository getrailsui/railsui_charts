# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org). While the version is below 1.0 the
public API may change between minor versions.

## [Unreleased]

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

[Unreleased]: https://github.com/getrailsui/railsui_charts/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/getrailsui/railsui_charts/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/getrailsui/railsui_charts/releases/tag/v0.1.0
