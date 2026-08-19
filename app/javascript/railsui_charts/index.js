// The package entry point.
//
// The controllers used to be copied into each application by a generator, which
// meant `bundle update` moved the Ruby and left the JavaScript on whatever
// version was installed. Importing them from here — over npm for a bundled app,
// over the asset pipeline for an importmap one — is what makes an upgrade
// actually arrive.

import RailsuiChartController from "../controllers/railsui_chart_controller.js"
import RailsuiChartFiltersController from "../controllers/railsui_chart_filters_controller.js"
import RailsuiMetricDialogController from "../controllers/railsui_metric_dialog_controller.js"

export { RailsuiChartController, RailsuiChartFiltersController, RailsuiMetricDialogController }

// The identifiers the Ruby helpers emit. Registering them by hand means three
// chances to typo a name that fails silently — a chart simply never draws, with
// nothing in the console to say why.
export const RAILSUI_CHART_CONTROLLERS = {
  "railsui-chart": RailsuiChartController,
  "railsui-chart-filters": RailsuiChartFiltersController,
  "railsui-metric-dialog": RailsuiMetricDialogController
}

export function registerRailsuiCharts(application) {
  Object.entries(RAILSUI_CHART_CONTROLLERS).forEach(([identifier, controller]) => {
    application.register(identifier, controller)
  })

  return application
}

export default registerRailsuiCharts
