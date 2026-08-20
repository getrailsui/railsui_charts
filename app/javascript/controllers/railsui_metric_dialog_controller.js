import { Controller } from "@hotwired/stimulus"

// Opens a metric card's expanded view: the same series with room to read it.
// A native <dialog> handles focus trapping, Escape, and inertness for us.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.classList.remove("railsui-metric-dialog--closing")
    this.dialogTarget.showModal()

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("railsui-metric-dialog--open")
      this.refreshCharts()
    })
  }

  close() {
    this.closeDialog()
  }

  cancel(event) {
    event.preventDefault()
    this.closeDialog()
  }

  // Clicking the backdrop lands on the dialog element itself; a click anywhere
  // inside lands on a child.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.closeDialog()
  }

  refreshCharts() {
    // The chart inside was laid out while the dialog was closed, which means
    // it measured zero and drew nothing. Now that it has a size, tell it.
    this.dialogTarget.querySelectorAll(".railsui-chart").forEach((chart) => {
      chart.dispatchEvent(new CustomEvent("railsui-chart:refresh"))
    })
  }

  closeDialog() {
    const dialog = this.dialogTarget
    if (!dialog.open) return

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      dialog.classList.remove("railsui-metric-dialog--open", "railsui-metric-dialog--closing")
      dialog.close()
      return
    }

    dialog.classList.remove("railsui-metric-dialog--open")
    dialog.classList.add("railsui-metric-dialog--closing")

    let closed = false
    const finish = () => {
      if (closed) return

      closed = true
      dialog.classList.remove("railsui-metric-dialog--closing")
      dialog.close()
    }

    dialog.addEventListener("transitionend", finish, { once: true })
    setTimeout(finish, 240)
  }
}
