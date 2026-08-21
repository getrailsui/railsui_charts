// app/javascript/controllers/railsui_chart_controller.js
import { Controller } from "@hotwired/stimulus";
import ApexCharts from "apexcharts";
var railsui_chart_controller_default = class extends Controller {
  static values = { options: Object };
  connect() {
    this.bindThemeListeners();
    this.refresh = this.refresh.bind(this);
    this.element.addEventListener("railsui-chart:refresh", this.refresh);
    this.watchViewport();
  }
  disconnect() {
    this.unwatchViewport();
    this.element.removeEventListener("railsui-chart:refresh", this.refresh);
    this.destroy();
    this.unbindThemeListeners();
  }
  // Building every chart at once is work the reader has not asked for, and a
  // page carrying a dozen of them spends the first seconds laying out charts
  // nobody is looking at. Each one waits until it is nearly on screen; the
  // server reserves its height so nothing shifts when it arrives.
  watchViewport() {
    if (!("IntersectionObserver" in window)) {
      if (this.measurable) this.render();
      return;
    }
    this.viewportObserver = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return;
        this.unwatchViewport();
        if (this.measurable) this.render();
      },
      // Start early enough that it is drawn by the time it is scrolled to.
      { rootMargin: "300px 0px" }
    );
    this.viewportObserver.observe(this.element);
  }
  unwatchViewport() {
    this.viewportObserver?.disconnect();
    this.viewportObserver = null;
  }
  // An explicit reveal outranks the viewport check — a dialog opening means
  // draw it now.
  refresh() {
    this.unwatchViewport();
    if (this.measurable) this.render();
  }
  rerender() {
    if (this.chart) this.render();
  }
  // Anything inside a `display: none` subtree — a closed <dialog>, a hidden
  // tab panel — reports no client rects.
  get measurable() {
    return this.element.getClientRects().length > 0;
  }
  render() {
    this.destroy();
    this.chart = new ApexCharts(this.element, this.resolvedOptions());
    this.chart.render();
  }
  destroy() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }
  resolvedOptions() {
    const options = this.resolveCssVariables({
      ...this.optionsValue,
      chart: {
        ...this.optionsValue.chart || {},
        animations: {
          ...this.optionsValue.chart?.animations || {},
          enabled: this.animationsEnabled
        }
      },
      theme: {
        ...this.optionsValue.theme,
        // Last word: the server ships a static `light` default it cannot know
        // better than, so spreading it after would pin every chart to light.
        mode: this.darkMode ? "dark" : "light"
      }
    });
    return this.applyTooltip(this.applyEdgeLabels(this.applyFormatters(options)));
  }
  // Apex's stock tooltip is a dark slab whatever the page is doing. This one is
  // built from the same CSS variables as everything else, so it follows the
  // theme, and it leads with what changed rather than with the date.
  applyTooltip(options) {
    if (options.tooltip_style === false) return options;
    if (options.tooltip?.custom) return options;
    const format = this.formatterFor(options.format || "number", options.currency);
    const rowFormats = (options.series_formats || []).map((name) => this.formatterFor(name, options.currency));
    const comparedDates = options.compare_categories || [];
    const upIsGood = options.trend_up_is_good !== false;
    const showDelta = options.tooltip_delta !== false;
    const headingMode = options.tooltip_heading;
    return {
      ...options,
      tooltip: {
        ...options.tooltip || {},
        custom: ({ series, seriesIndex, dataPointIndex, w }) => {
          const labels = w.globals.categoryLabels?.length ? w.globals.categoryLabels : w.globals.labels;
          if (options.chart?.type === "rangeBar") {
            return this.rangeBarTooltipMarkup({ series, seriesIndex, dataPointIndex, w }, options, format);
          }
          const configuredPoint = this.configuredPoint(options, w, seriesIndex, dataPointIndex);
          if (this.labelledPoint(configuredPoint)) {
            return this.labelledPointTooltipMarkup({ series, seriesIndex, dataPointIndex, w }, options, format);
          }
          if (!Array.isArray(series[0])) {
            const slice = seriesIndex ?? dataPointIndex;
            const row = { label: "", value: series[slice], color: w.globals.colors[slice], format: rowFormats[slice] || null };
            return this.tooltipMarkup(labels?.[slice], [row], null, format);
          }
          const point = (index) => series[index]?.[dataPointIndex];
          const comparing = series.length === 2 && comparedDates.length > 0;
          const rows = series.map((_, index) => ({
            // In a comparison the two rows are the same metric at different
            // dates, so the date identifies them. Otherwise the name does.
            label: comparing ? index === 0 ? labels?.[dataPointIndex] : comparedDates[dataPointIndex] : w.globals.seriesNames[index],
            value: point(index),
            color: w.globals.colors[index],
            format: rowFormats[index] || null
          }));
          const leadsWithSeries = headingMode ? headingMode === "series" : comparing;
          const heading = leadsWithSeries ? w.globals.seriesNames[0] : labels?.[dataPointIndex];
          const delta = showDelta && comparing ? this.tooltipDelta(point(0), point(1), upIsGood) : null;
          return this.tooltipMarkup(heading, rows, delta, format);
        }
      }
    };
  }
  configuredPoint(options, w, seriesIndex, dataPointIndex) {
    return (w.config?.series?.[seriesIndex] || options.series?.[seriesIndex] || {}).data?.[dataPointIndex];
  }
  labelledPoint(point) {
    return point !== null && typeof point === "object" && !Array.isArray(point) && "x" in point && "y" in point;
  }
  labelledPointTooltipMarkup({ series, seriesIndex, dataPointIndex, w }, options, format) {
    const configuredSeries = w.config?.series?.[seriesIndex] || options.series?.[seriesIndex] || {};
    const point = this.configuredPoint(options, w, seriesIndex, dataPointIndex) || {};
    const title = point.name || point.label || point.x || configuredSeries.name;
    if (Array.isArray(point.y)) {
      return this.arrayPointTooltipMarkup(point, configuredSeries, options, w, seriesIndex, dataPointIndex, format);
    }
    const row = {
      label: configuredSeries.name || "Value",
      value: point.y ?? series?.[seriesIndex]?.[dataPointIndex],
      color: this.pointColor(options, w, seriesIndex, dataPointIndex),
      format: null
    };
    return this.tooltipMarkup(title, [row], null, format);
  }
  arrayPointTooltipMarkup(point, configuredSeries, options, w, seriesIndex, dataPointIndex, format) {
    const labels = options.tooltip_value_labels || this.defaultArrayValueLabels(options.chart?.type, point.y.length);
    const color = this.pointColor(options, w, seriesIndex, dataPointIndex);
    const rows = point.y.map((value, index) => ({
      label: labels[index] || `Value ${index + 1}`,
      value,
      color,
      format: null
    }));
    if (point.v !== void 0 && point.v !== null) {
      rows.push({
        label: options.tooltip_volume_label || "Volume",
        value: point.v,
        color,
        format: this.formatterFor(options.volume_format || "human", options.currency)
      });
    }
    return this.tooltipMarkup(point.name || point.label || point.x || configuredSeries.name, rows, null, format);
  }
  defaultArrayValueLabels(type, length) {
    if (type === "candlestick" && length === 4) return ["Open", "High", "Low", "Close"];
    if (type === "boxPlot" && length === 5) return ["Min", "Q1", "Median", "Q3", "Max"];
    if (type === "rangeArea" && length === 2) return ["Low", "High"];
    return [];
  }
  rangeBarTooltipMarkup({ series, seriesIndex, dataPointIndex, w }, options, format) {
    const configuredSeries = w.config?.series?.[seriesIndex] || options.series?.[seriesIndex] || {};
    const point = configuredSeries.data?.[dataPointIndex] || {};
    const fallbackValue = series?.[seriesIndex]?.[dataPointIndex];
    const value = Array.isArray(point.y) ? point.y : fallbackValue;
    const title = point.name || point.label || point.meta?.label || point.x || w.globals.categoryLabels?.[dataPointIndex] || w.globals.labels?.[dataPointIndex] || configuredSeries.name;
    const rowLabel = point.name || point.label || point.meta?.label ? point.x || configuredSeries.name || "Range" : "Range";
    const row = {
      label: rowLabel,
      value: this.formatRangeValue(value, options, format),
      color: this.pointColor(options, w, seriesIndex, dataPointIndex),
      format: null
    };
    return this.tooltipMarkup(title, [row], null, null);
  }
  pointColor(options, w, seriesIndex, dataPointIndex) {
    if (options.plotOptions?.bar?.distributed && Array.isArray(options.colors)) {
      return options.colors[dataPointIndex] || w.globals.colors?.[dataPointIndex] || w.globals.colors?.[seriesIndex];
    }
    if (options.plotOptions?.treemap?.distributed && Array.isArray(options.colors)) {
      return options.colors[dataPointIndex] || w.globals.colors?.[dataPointIndex] || w.globals.colors?.[seriesIndex];
    }
    return w.globals.colors?.[seriesIndex] || options.colors?.[seriesIndex] || options.colors?.[0];
  }
  formatRangeValue(value, options, format) {
    const values = Array.isArray(value) ? value : [value];
    const present = values.filter((entry) => entry !== null && entry !== void 0);
    if (present.length === 0) return null;
    if (present.length === 2 && present.every((entry) => this.timestampLike(entry))) {
      const [start, finish] = present;
      if (this.sameTimestampDay(start, finish, options)) {
        const startTime = this.formatTimestampTime(start, options);
        const finishTime = this.formatTimestampTime(finish, options);
        return startTime === finishTime ? `${this.formatTimestampDate(start, options)}, ${startTime}` : `${this.formatTimestampDate(start, options)}, ${startTime} - ${finishTime}`;
      }
    }
    const formatted = present.map((entry) => this.formatRangeEndpoint(entry, options, format));
    if (formatted.length === 1 || formatted[0] === formatted[1]) return formatted[0];
    return `${formatted[0]} - ${formatted[formatted.length - 1]}`;
  }
  formatRangeEndpoint(value, options, format) {
    if (this.timestampLike(value)) return `${this.formatTimestampDate(value, options)}, ${this.formatTimestampTime(value, options)}`;
    if (format) return format(value);
    return value;
  }
  timestampLike(value) {
    return typeof value === "number" && Number.isFinite(value) && Math.abs(value) >= 1e11;
  }
  sameTimestampDay(left, right, options) {
    const leftDate = new Date(left);
    const rightDate = new Date(right);
    if (this.datetimeUTC(options)) {
      return leftDate.toISOString().slice(0, 10) === rightDate.toISOString().slice(0, 10);
    }
    return leftDate.getFullYear() === rightDate.getFullYear() && leftDate.getMonth() === rightDate.getMonth() && leftDate.getDate() === rightDate.getDate();
  }
  formatTimestampDate(value, options) {
    return new Intl.DateTimeFormat("en-US", {
      ...this.datetimeUTC(options) ? { timeZone: "UTC" } : {},
      month: "short",
      day: "numeric"
    }).format(new Date(value));
  }
  formatTimestampTime(value, options) {
    return new Intl.DateTimeFormat("en-US", {
      ...this.datetimeUTC(options) ? { timeZone: "UTC" } : {},
      hour: "numeric",
      minute: "2-digit"
    }).format(new Date(value));
  }
  datetimeUTC(options) {
    return options.xaxis?.labels?.datetimeUTC !== false;
  }
  tooltipDelta(current, previous, upIsGood) {
    if (![current, previous].every((n) => typeof n === "number") || previous === 0) return null;
    const change = (current - previous) / Math.abs(previous) * 100;
    if (!isFinite(change)) return null;
    const rounded = Math.round(change * 100) / 100;
    return {
      text: `${rounded > 0 ? "+" : ""}${rounded}%`,
      tone: rounded === 0 ? "neutral" : rounded > 0 === upIsGood ? "positive" : "negative"
    };
  }
  tooltipMarkup(heading, rows, delta, format) {
    const cells = rows.filter((row) => row.value !== null && row.value !== void 0).map(
      (row) => `
          <tr>
            <th scope="row">
              <span class="railsui-chart-tooltip__key" style="background:${this.escape(row.color)}"></span>
              ${this.escape(row.label)}
            </th>
            <td>${this.escape(this.formatRow(row, format))}</td>
          </tr>`
    ).join("");
    const badge = delta ? `<span class="railsui-chart-tooltip__delta railsui-chart-tooltip__delta--${delta.tone}">${this.escape(delta.text)}</span>` : "";
    return `
      <div class="railsui-chart-tooltip">
        <div class="railsui-chart-tooltip__head">
          <span class="railsui-chart-tooltip__title">${this.escape(heading)}</span>${badge}
        </div>
        <table class="railsui-chart-tooltip__rows">${cells}</table>
      </div>`;
  }
  // A row's own formatter when it has one, the chart's otherwise.
  formatRow(row, fallback) {
    const format = row.format || fallback;
    return format ? format(row.value) : row.value;
  }
  // Series names and category labels come from application data.
  escape(value) {
    return String(value ?? "").replace(/[&<>"']/g, (char) => {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char];
    });
  }
  // Stripe-style cards label only the first and last tick, so the axis reads as
  // a range rather than a row of collided, rotated dates.
  applyEdgeLabels(options) {
    if (!options.edge_labels) return options;
    const categories = options.xaxis?.categories || [];
    const last = categories.length - 1;
    return {
      ...options,
      xaxis: {
        ...options.xaxis || {},
        labels: {
          ...options.xaxis?.labels || {},
          formatter: (value, _timestamp, opts) => {
            const index = typeof opts?.i === "number" ? opts.i : categories.indexOf(value);
            return index === 0 || index === last ? value : "";
          }
        }
      },
      // Apex reuses the axis formatter for the tooltip title, which would blank
      // out every point between the two edges.
      tooltip: {
        ...options.tooltip || {},
        x: {
          ...options.tooltip?.x || {},
          formatter: (value, opts) => categories[opts?.dataPointIndex] ?? value
        }
      }
    };
  }
  applyFormatters(options) {
    const formatter = this.formatterFor(options.format || "number", options.currency);
    if (!formatter) return options;
    const withFormatter = (axis) => {
      if (Array.isArray(axis)) return axis.map(withFormatter);
      const own = axis?.format ? this.formatterFor(axis.format, options.currency) : null;
      return { ...axis || {}, labels: { ...axis?.labels || {}, formatter: own || formatter } };
    };
    if (options.plotOptions?.bar?.horizontal) {
      const timeAxis = options.xaxis?.type === "datetime";
      return {
        ...options,
        ...timeAxis ? {} : { xaxis: withFormatter(options.xaxis) },
        tooltip: { ...options.tooltip || {}, y: { ...options.tooltip?.y || {}, formatter } }
      };
    }
    const formatted = {
      ...options,
      yaxis: withFormatter(options.yaxis),
      tooltip: {
        ...options.tooltip || {},
        y: {
          ...options.tooltip?.y || {},
          formatter
        }
      }
    };
    if (Array.isArray(options.responsive)) {
      formatted.responsive = options.responsive.map((entry) => ({
        ...entry,
        options: {
          ...entry.options || {},
          ...entry.options?.yaxis ? { yaxis: withFormatter(entry.options.yaxis) } : {}
        }
      }));
    }
    return formatted;
  }
  formatterFor(format, currency = "$") {
    switch (format) {
      case "currency":
        return (value) => {
          if (value === null || value === void 0 || isNaN(value)) return value;
          return `${currency}${Number(value).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
        };
      case "percentage":
        return (value) => {
          if (value === null || value === void 0 || isNaN(value)) return value;
          return `${Number(value).toFixed(1)}%`;
        };
      case "human":
        return (value) => {
          if (value === null || value === void 0 || isNaN(value)) return value;
          return this.humanFormat(Number(value));
        };
      case "short_currency":
        return (value) => {
          if (value === null || value === void 0 || isNaN(value)) return value;
          return `${currency}${this.humanFormat(Number(value))}`;
        };
      case "number":
        return (value) => {
          if (value === null || value === void 0 || isNaN(value)) return value;
          return Number(value).toLocaleString("en-US", { maximumFractionDigits: 2 });
        };
      default:
        return null;
    }
  }
  humanFormat(value) {
    if (value === 0) return "0";
    const suffixes = ["", "K", "M", "B", "T"];
    const tier = Math.log10(Math.abs(value)) / 3 | 0;
    if (tier === 0) return `${Math.round(value * 100) / 100}`;
    const scaled = value / Math.pow(10, tier * 3);
    const rounded = Math.round(scaled * 10) / 10;
    return `${Number.isInteger(rounded) ? rounded : rounded.toFixed(1)}${suffixes[tier]}`;
  }
  resolveCssVariables(value) {
    if (typeof value === "string") {
      return this.resolveCssVariable(value);
    }
    if (Array.isArray(value)) {
      return value.map((item) => this.resolveCssVariables(item));
    }
    if (value !== null && typeof value === "object") {
      return Object.entries(value).reduce((result, [key, val]) => {
        result[key] = this.resolveCssVariables(val);
        return result;
      }, {});
    }
    return value;
  }
  resolveCssVariable(value) {
    const match = value.match(/^var\((--[^,]+)(?:,\s*(.+))?\)$/);
    if (!match) return value;
    const variableName = match[1];
    const fallback = match[2];
    const computed = getComputedStyle(this.element).getPropertyValue(variableName).trim();
    return computed || fallback || value;
  }
  bindThemeListeners() {
    this.darkModeMediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    this.motionMediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.themeHandler = () => this.rerender();
    this.darkModeMediaQuery.addEventListener("change", this.themeHandler);
    this.motionMediaQuery.addEventListener("change", this.themeHandler);
    this.renderedDarkMode = this.darkMode;
    this.themeObserver = new MutationObserver(() => {
      const dark = this.darkMode;
      if (dark === this.renderedDarkMode) return;
      this.renderedDarkMode = dark;
      this.rerender();
    });
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class", "data-theme"]
    });
  }
  unbindThemeListeners() {
    if (this.themeHandler) {
      this.darkModeMediaQuery?.removeEventListener("change", this.themeHandler);
      this.motionMediaQuery?.removeEventListener("change", this.themeHandler);
    }
    this.themeObserver?.disconnect();
  }
  get animationsEnabled() {
    return !(this.motionMediaQuery && this.motionMediaQuery.matches);
  }
  get darkMode() {
    const root = document.documentElement;
    const explicit = root.getAttribute("data-theme");
    if (explicit === "dark") return true;
    if (explicit === "light") return false;
    if (root.classList.contains("dark")) return true;
    return this.darkModeMediaQuery ? this.darkModeMediaQuery.matches : false;
  }
};

// app/javascript/controllers/railsui_chart_filters_controller.js
import { Controller as Controller2 } from "@hotwired/stimulus";
var railsui_chart_filters_controller_default = class extends Controller2 {
  submit() {
    if (this.element.requestSubmit) {
      this.element.requestSubmit();
    } else {
      this.element.submit();
    }
  }
};

// app/javascript/controllers/railsui_metric_dialog_controller.js
import { Controller as Controller3 } from "@hotwired/stimulus";
var railsui_metric_dialog_controller_default = class extends Controller3 {
  static targets = ["dialog"];
  open() {
    this.dialogTarget.classList.remove("railsui-metric-dialog--closing");
    this.dialogTarget.showModal();
    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("railsui-metric-dialog--open");
      this.refreshCharts();
    });
  }
  close() {
    this.closeDialog();
  }
  cancel(event) {
    event.preventDefault();
    this.closeDialog();
  }
  // Clicking the backdrop lands on the dialog element itself; a click anywhere
  // inside lands on a child.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.closeDialog();
  }
  refreshCharts() {
    this.dialogTarget.querySelectorAll(".railsui-chart").forEach((chart) => {
      chart.dispatchEvent(new CustomEvent("railsui-chart:refresh"));
    });
  }
  closeDialog() {
    const dialog = this.dialogTarget;
    if (!dialog.open) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      dialog.classList.remove("railsui-metric-dialog--open", "railsui-metric-dialog--closing");
      dialog.close();
      return;
    }
    dialog.classList.remove("railsui-metric-dialog--open");
    dialog.classList.add("railsui-metric-dialog--closing");
    let closed = false;
    const finish = () => {
      if (closed) return;
      closed = true;
      dialog.classList.remove("railsui-metric-dialog--closing");
      dialog.close();
    };
    dialog.addEventListener("transitionend", finish, { once: true });
    setTimeout(finish, 240);
  }
};

// app/javascript/railsui_charts/index.js
var RAILSUI_CHART_CONTROLLERS = {
  "railsui-chart": railsui_chart_controller_default,
  "railsui-chart-filters": railsui_chart_filters_controller_default,
  "railsui-metric-dialog": railsui_metric_dialog_controller_default
};
function registerRailsuiCharts(application) {
  Object.entries(RAILSUI_CHART_CONTROLLERS).forEach(([identifier, controller]) => {
    application.register(identifier, controller);
  });
  return application;
}
var index_default = registerRailsuiCharts;
export {
  RAILSUI_CHART_CONTROLLERS,
  railsui_chart_controller_default as RailsuiChartController,
  railsui_chart_filters_controller_default as RailsuiChartFiltersController,
  railsui_metric_dialog_controller_default as RailsuiMetricDialogController,
  index_default as default,
  registerRailsuiCharts
};
