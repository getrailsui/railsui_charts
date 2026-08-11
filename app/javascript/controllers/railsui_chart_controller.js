import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    this.render()
  }

  disconnect() {
    this.destroy()
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
    return {
      ...this.optionsValue,
      theme: {
        mode: this.darkMode ? "dark" : "light",
        ...this.optionsValue.theme
      }
    }
  }

  get darkMode() {
    const root = document.documentElement
    const explicit = root.getAttribute("data-theme")

    if (explicit === "dark") return true
    if (explicit === "light") return false

    return window.matchMedia("(prefers-color-scheme: dark)").matches
  }
}
