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
    return this.resolveCssVariables({
      ...this.optionsValue,
      theme: {
        mode: this.darkMode ? "dark" : "light",
        ...this.optionsValue.theme
      }
    })
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
