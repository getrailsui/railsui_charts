import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    this.render()
    this.bindDarkModeListener()
  }

  disconnect() {
    this.destroy()
    this.unbindDarkModeListener()
  }

  render() {
    this.destroy()
    const options = this.resolvedOptions()
    this.chart = new ApexCharts(this.element, options)
    this.chart.render()
  }

  destroy() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  resolvedOptions() {
    return this.applyFormatters(this.resolveCssVariables({
      ...this.optionsValue,
      theme: {
        mode: this.darkMode ? "dark" : "light",
        ...this.optionsValue.theme
      }
    }))
  }

  applyFormatters(options) {
    const format = options.format
    if (!format || format === "number") return options

    const formatter = this.formatterFor(format, options.currency)
    if (!formatter) return options

    const yaxis = Array.isArray(options.yaxis) ? options.yaxis : [options.yaxis || {}]
    const formattedYaxis = yaxis.map((axis) => ({
      ...axis,
      labels: {
        ...(axis.labels || {}),
        formatter: formatter
      }
    }))

    return {
      ...options,
      yaxis: Array.isArray(options.yaxis) ? formattedYaxis : formattedYaxis[0],
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
      default:
        return null
    }
  }

  humanFormat(value) {
    const suffixes = ["", "k", "M", "B", "T"]
    const tier = Math.log10(Math.abs(value)) / 3 | 0
    if (tier === 0) return value.toString()
    const suffix = suffixes[tier]
    const scale = Math.pow(10, tier * 3)
    const scaled = value / scale
    return `${scaled.toFixed(1)}${suffix}`
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
    const computed = getComputedStyle(document.documentElement).getPropertyValue(variableName).trim()

    return computed || fallback || value
  }

  bindDarkModeListener() {
    this.darkModeMediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.darkModeHandler = () => this.render()
    this.darkModeMediaQuery.addEventListener("change", this.darkModeHandler)
  }

  unbindDarkModeListener() {
    if (this.darkModeMediaQuery && this.darkModeHandler) {
      this.darkModeMediaQuery.removeEventListener("change", this.darkModeHandler)
    }
  }

  get darkMode() {
    const root = document.documentElement
    const explicit = root.getAttribute("data-theme")

    if (explicit === "dark") return true
    if (explicit === "light") return false

    return this.darkModeMediaQuery ? this.darkModeMediaQuery.matches : false
  }
}
