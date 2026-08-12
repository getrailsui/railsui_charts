import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    // Bind before the first render: the theme getter reads the media query, so
    // rendering first paints every chart light on a dark OS.
    this.bindThemeListeners()
    this.render()

    // Apex measures the element as it renders. Anything hidden at connect — a
    // closed dialog, a collapsed panel — measures zero and draws nothing, so
    // whatever reveals it says so and the chart lays itself out.
    this.refresh = this.refresh.bind(this)
    this.element.addEventListener("railsui-chart:refresh", this.refresh)
  }

  disconnect() {
    this.element.removeEventListener("railsui-chart:refresh", this.refresh)
    this.destroy()
    this.unbindThemeListeners()
  }

  refresh() {
    this.render()
  }

  render() {
    this.destroy()
    this.chart = new ApexCharts(this.element, this.resolvedOptions())
    this.chart.render()
  }

  destroy() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  resolvedOptions() {
    const options = this.resolveCssVariables({
      ...this.optionsValue,
      chart: {
        ...(this.optionsValue.chart || {}),
        animations: {
          ...(this.optionsValue.chart?.animations || {}),
          enabled: this.animationsEnabled
        }
      },
      theme: {
        ...this.optionsValue.theme,
        // Last word: the server ships a static `light` default it cannot know
        // better than, so spreading it after would pin every chart to light.
        mode: this.darkMode ? "dark" : "light"
      }
    })

    return this.applyTooltip(this.applyEdgeLabels(this.applyFormatters(options)))
  }

  // Apex's stock tooltip is a dark slab whatever the page is doing. This one is
  // built from the same CSS variables as everything else, so it follows the
  // theme, and it leads with what changed rather than with the date.
  applyTooltip(options) {
    if (options.tooltip?.custom || options.chart?.sparkline?.enabled) return options

    const format = this.formatterFor(options.format || "number", options.currency)
    const comparedDates = options.compare_categories || []
    const upIsGood = options.trend_up_is_good !== false

    return {
      ...options,
      tooltip: {
        ...(options.tooltip || {}),
        custom: ({ series, dataPointIndex, w }) => {
          const labels = w.globals.categoryLabels?.length ? w.globals.categoryLabels : w.globals.labels
          const point = (index) => series[index]?.[dataPointIndex]
          const comparing = series.length === 2 && comparedDates.length > 0

          const rows = series.map((_, index) => ({
            // In a comparison the two rows are the same metric at different
            // dates, so the date identifies them. Otherwise the name does.
            label: comparing
              ? (index === 0 ? labels?.[dataPointIndex] : comparedDates[dataPointIndex])
              : w.globals.seriesNames[index],
            value: point(index),
            color: w.globals.colors[index]
          }))

          const heading = comparing ? w.globals.seriesNames[0] : labels?.[dataPointIndex]
          return this.tooltipMarkup(heading, rows, comparing ? this.tooltipDelta(point(0), point(1), upIsGood) : null, format)
        }
      }
    }
  }

  tooltipDelta(current, previous, upIsGood) {
    if (![current, previous].every((n) => typeof n === "number") || previous === 0) return null

    const change = ((current - previous) / Math.abs(previous)) * 100
    if (!isFinite(change)) return null

    const rounded = Math.round(change * 100) / 100
    return {
      text: `${rounded > 0 ? "+" : ""}${rounded}%`,
      tone: rounded === 0 ? "neutral" : (rounded > 0) === upIsGood ? "positive" : "negative"
    }
  }

  tooltipMarkup(heading, rows, delta, format) {
    const cells = rows
      .filter((row) => row.value !== null && row.value !== undefined)
      .map(
        (row) => `
          <tr>
            <th scope="row">
              <span class="railsui-chart-tooltip__key" style="background:${this.escape(row.color)}"></span>
              ${this.escape(row.label)}
            </th>
            <td>${this.escape(format ? format(row.value) : row.value)}</td>
          </tr>`
      )
      .join("")

    const badge = delta
      ? `<span class="railsui-chart-tooltip__delta railsui-chart-tooltip__delta--${delta.tone}">${this.escape(delta.text)}</span>`
      : ""

    return `
      <div class="railsui-chart-tooltip">
        <div class="railsui-chart-tooltip__head">
          <span class="railsui-chart-tooltip__title">${this.escape(heading)}</span>${badge}
        </div>
        <table class="railsui-chart-tooltip__rows">${cells}</table>
      </div>`
  }

  // Series names and category labels come from application data.
  escape(value) {
    return String(value ?? "").replace(/[&<>"']/g, (char) => {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]
    })
  }

  // Stripe-style cards label only the first and last tick, so the axis reads as
  // a range rather than a row of collided, rotated dates.
  applyEdgeLabels(options) {
    if (!options.edge_labels) return options

    const categories = options.xaxis?.categories || []
    const last = categories.length - 1

    return {
      ...options,
      xaxis: {
        ...(options.xaxis || {}),
        labels: {
          ...(options.xaxis?.labels || {}),
          formatter: (value, _timestamp, opts) => {
            const index = typeof opts?.i === "number" ? opts.i : categories.indexOf(value)
            return index === 0 || index === last ? value : ""
          }
        }
      },
      // Apex reuses the axis formatter for the tooltip title, which would blank
      // out every point between the two edges.
      tooltip: {
        ...(options.tooltip || {}),
        x: {
          ...(options.tooltip?.x || {}),
          formatter: (value, opts) => categories[opts?.dataPointIndex] ?? value
        }
      }
    }
  }

  applyFormatters(options) {
    const formatter = this.formatterFor(options.format || "number", options.currency)
    if (!formatter) return options

    const withFormatter = (axis) => {
      if (Array.isArray(axis)) return axis.map(withFormatter)
      return { ...(axis || {}), labels: { ...(axis?.labels || {}), formatter: formatter } }
    }

    return {
      ...options,
      yaxis: withFormatter(options.yaxis),
      // Breakpoint overrides replace the axis rather than merging into it, so
      // an unformatted mobile axis is the default unless the formatter is
      // planted in each one too.
      responsive: Array.isArray(options.responsive)
        ? options.responsive.map((entry) => ({
            ...entry,
            options: {
              ...(entry.options || {}),
              ...(entry.options?.yaxis ? { yaxis: withFormatter(entry.options.yaxis) } : {})
            }
          }))
        : options.responsive,
      tooltip: {
        ...(options.tooltip || {}),
        y: {
          ...(options.tooltip?.y || {}),
          formatter: formatter
        }
      }
    }
  }

  formatterFor(format, currency = "$") {
    switch (format) {
      case "currency":
        return (value) => {
          if (value === null || value === undefined || isNaN(value)) return value
          return `${currency}${Number(value).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`
        }
      case "percentage":
        return (value) => {
          if (value === null || value === undefined || isNaN(value)) return value
          return `${Number(value).toFixed(1)}%`
        }
      case "human":
        return (value) => {
          if (value === null || value === undefined || isNaN(value)) return value
          return this.humanFormat(Number(value))
        }
      case "short_currency":
        return (value) => {
          if (value === null || value === undefined || isNaN(value)) return value
          return `${currency}${this.humanFormat(Number(value))}`
        }
      case "number":
        // Computed series arrive as floats, so an unformatted axis renders
        // "860.0000000000000". Delimited and trimmed by default.
        return (value) => {
          if (value === null || value === undefined || isNaN(value)) return value
          return Number(value).toLocaleString("en-US", { maximumFractionDigits: 2 })
        }
      default:
        return null
    }
  }

  humanFormat(value) {
    if (value === 0) return "0"

    const suffixes = ["", "K", "M", "B", "T"]
    const tier = Math.log10(Math.abs(value)) / 3 | 0
    if (tier === 0) return `${Math.round(value * 100) / 100}`

    const scaled = value / Math.pow(10, tier * 3)
    // 2.0K reads worse than 2K; only keep the decimal when it carries meaning.
    const rounded = Math.round(scaled * 10) / 10
    return `${Number.isInteger(rounded) ? rounded : rounded.toFixed(1)}${suffixes[tier]}`
  }

  resolveCssVariables(value) {
    if (typeof value === "string") {
      return this.resolveCssVariable(value)
    }

    if (Array.isArray(value)) {
      return value.map((item) => this.resolveCssVariables(item))
    }

    if (value !== null && typeof value === "object") {
      return Object.entries(value).reduce((result, [key, val]) => {
        result[key] = this.resolveCssVariables(val)
        return result
      }, {})
    }

    return value
  }

  resolveCssVariable(value) {
    const match = value.match(/^var\((--[^,]+)(?:,\s*(.+))?\)$/)
    if (!match) return value

    const variableName = match[1]
    const fallback = match[2]
    // Read from the chart's own element so a scoped theme (a dark panel inside
    // a light page) resolves against the surface it actually sits on.
    const computed = getComputedStyle(this.element).getPropertyValue(variableName).trim()

    return computed || fallback || value
  }

  bindThemeListeners() {
    this.darkModeMediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.motionMediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.themeHandler = () => this.render()

    this.darkModeMediaQuery.addEventListener("change", this.themeHandler)
    this.motionMediaQuery.addEventListener("change", this.themeHandler)

    // Class- and attribute-based theme toggles never fire a media query event,
    // so watch the root element for the swap too.
    this.renderedDarkMode = this.darkMode
    this.themeObserver = new MutationObserver(() => {
      const dark = this.darkMode
      if (dark === this.renderedDarkMode) return

      this.renderedDarkMode = dark
      this.render()
    })
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class", "data-theme"]
    })
  }

  unbindThemeListeners() {
    if (this.themeHandler) {
      this.darkModeMediaQuery?.removeEventListener("change", this.themeHandler)
      this.motionMediaQuery?.removeEventListener("change", this.themeHandler)
    }
    this.themeObserver?.disconnect()
  }

  get animationsEnabled() {
    return !(this.motionMediaQuery && this.motionMediaQuery.matches)
  }

  get darkMode() {
    const root = document.documentElement
    const explicit = root.getAttribute("data-theme")

    if (explicit === "dark") return true
    if (explicit === "light") return false
    if (root.classList.contains("dark")) return true

    return this.darkModeMediaQuery ? this.darkModeMediaQuery.matches : false
  }
}
