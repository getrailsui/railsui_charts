# Pins for applications using importmap-rails.
#
# The engine adds this file to the app's importmap paths, so an importmap app
# gets the same bare specifier a bundled app uses:
#
#   import { registerRailsuiCharts } from "@getrailsui/charts"
#
# It points at a prebuilt, self-contained file rather than at the individual
# controllers. Sprockets digests every asset separately, so the relative imports
# between the source files would not resolve once served — the browser would ask
# for an undigested path and get a 404 with the chart simply never appearing.
pin "@getrailsui/charts", to: "railsui_charts.js", preload: true
