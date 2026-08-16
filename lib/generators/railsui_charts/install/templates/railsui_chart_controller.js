import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    // Bind before the first render: the theme getter reads the media query, so
    // rendering first paints every chart light on a dark OS.
    this.bindThemeListeners()

    // Apex measures the element as it renders. Anything hidden at connect — a
    // closed dialog, a collapsed panel — measures zero and draws nothing, so
    // there is no point building it yet. Whatever reveals it says so, and the
    // chart lays itself out then.
    this.refresh = this.refresh.bind(this)
    this.element.addEventListener("railsui-chart:refresh", this.refresh)

    this.watchViewport()
  }

  disconnect() {
    this.unwatchViewport()
    this.element.removeEventListener("railsui-chart:refresh", this.refresh)
    this.destroy()
    this.unbindThemeListeners()
  }

  // Building every chart at once is work the reader has not asked for, and a
  // page carrying a dozen of them spends the first seconds laying out charts
  // nobody is looking at. Each one waits until it is nearly on screen; the
  // server reserves its height so nothing shifts when it arrives.
  watchViewport() {
    if (!("IntersectionObserver" in window)) {
      if (this.measurable) this.render()
      return
    }

    this.viewportObserver = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return

        this.unwatchViewport()
        if (this.measurable) this.render()
      },
      // Start early enough that it is drawn by the time it is scrolled to.
      { rootMargin: "300px 0px" }
    )

    this.viewportObserver.observe(this.element)
  }

  unwatchViewport() {
    this.viewportObserver?.disconnect()
    this.viewportObserver = null
  }

  // An explicit reveal outranks the viewport check — a dialog opening means
  // draw it now.
  refresh() {
    this.unwatchViewport()
    if (this.measurable) this.render()
  }

  rerender() {
    if (this.chart) this.render()
  }

  // Anything inside a `display: none` subtree — a closed <dialog>, a hidden
  // tab panel — reports no client rects.
  get measurable() {
    return this.element.getClientRects().length > 0
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
    // `tooltip_style: false` hands the tooltip back to Apex; passing your own
    // `tooltip.custom` also wins.
    if (options.tooltip_style === false) return options
    if (options.tooltip?.custom || options.chart?.sparkline?.enabled) return options

    const format = this.formatterFor(options.format || "number", options.currency)
    // One formatter per series on a combo, so a currency row and a percentage
    // row in the same tooltip each read in their own units.
    const rowFormats = (options.series_formats || []).map((name) => this.formatterFor(name, options.currency))
    const comparedDates = options.compare_categories || []
    const upIsGood = options.trend_up_is_good !== false
    const showDelta = options.tooltip_delta !== false
    const headingMode = options.tooltip_heading

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
            color: w.globals.colors[index],
            format: rowFormats[index] || null
          }))

          // Auto: a comparison leads with the metric, since the rows carry the
          // dates. Anything else leads with the point being hovered.
          const leadsWithSeries = headingMode ? headingMode === "series" : comparing
          const heading = leadsWithSeries ? w.globals.seriesNames[0] : labels?.[dataPointIndex]
          const delta = showDelta && comparing ? this.tooltipDelta(point(0), point(1), upIsGood) : null

          return this.tooltipMarkup(heading, rows, delta, format)
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
            <td>${this.escape(this.formatRow(row, format))}</td>
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

  // A row's own formatter when it has one, the chart's otherwise.
  formatRow(row, fallback) {
    const format = row.format || fallback
    return format ? format(row.value) : row.value
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

      // An axis may name its own format. A combo measures money on one side
      // and a percentage on the other, and one formatter across both dresses
      // one of the two scales in the wrong units.
      const own = axis?.format ? this.formatterFor(axis.format, options.currency) : null

      return { ...(axis || {}), labels: { ...(axis?.labels || {}), formatter: own || formatter } }
    }

    // A horizontal bar puts its values along x and its categories up y, so
    // formatting the y-axis there would dress the labels and leave the numbers
    // bare.
    if (options.plotOptions?.bar?.horizontal) {
      // Unless it is a time axis. A timeline's x values are milliseconds, and a
      // number formatter over the top turns every tick into "1,786,380,000,000"
      // where a date belongs. Apex formats a datetime axis from the date
      // itself, so the right move is to leave it alone.
      const timeAxis = options.xaxis?.type === "datetime"

      return {
        ...options,
        ...(timeAxis ? {} : { xaxis: withFormatter(options.xaxis) }),
        tooltip: { ...(options.tooltip || {}), y: { ...(options.tooltip?.y || {}), formatter: formatter } }
      }
    }

    const formatted = {
      ...options,
      yaxis: withFormatter(options.yaxis),
      tooltip: {
        ...(options.tooltip || {}),
        y: {
          ...(options.tooltip?.y || {}),
          formatter: formatter
        }
      }
    }

    // Only when there is one. Apex reads `responsive` as a list, and writing
    // the key back as undefined is not the same as leaving it out — it finds
    // the key, walks it, and throws before anything is drawn. A sparkline
    // never gets breakpoints, so every one of them hit this and rendered as
    // an empty element with no error in the console.
    if (Array.isArray(options.responsive)) {
      // Breakpoint overrides replace the axis rather than merging into it, so
      // an unformatted mobile axis is the default unless the formatter is
      // planted in each one too.
      formatted.responsive = options.responsive.map((entry) => ({
        ...entry,
        options: {
          ...(entry.options || {}),
          ...(entry.options?.yaxis ? { yaxis: withFormatter(entry.options.yaxis) } : {})
        }
      }))
    }

    return formatted
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
    // Only redraw what is already drawn. A chart still waiting for the
    // viewport should keep waiting rather than be pulled forward by a theme
    // change it is not on screen for.
    this.themeHandler = () => this.rerender()

    this.darkModeMediaQuery.addEventListener("change", this.themeHandler)
    this.motionMediaQuery.addEventListener("change", this.themeHandler)

    // Class- and attribute-based theme toggles never fire a media query event,
    // so watch the root element for the swap too.
    this.renderedDarkMode = this.darkMode
    this.themeObserver = new MutationObserver(() => {
      const dark = this.darkMode
      if (dark === this.renderedDarkMode) return

      this.renderedDarkMode = dark
      this.rerender()
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
