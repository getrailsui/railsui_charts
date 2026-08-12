import { Controller } from "@hotwired/stimulus"

// Opens a metric card's expanded view: the same series with room to read it.
// A native <dialog> handles focus trapping, Escape, and inertness for us.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()

    // The chart inside was laid out while the dialog was closed, which means
    // it measured zero and drew nothing. Now that it has a size, tell it.
    this.dialogTarget.querySelectorAll(".railsui-chart").forEach((chart) => {
      chart.dispatchEvent(new CustomEvent("railsui-chart:refresh"))
    })
  }

  close() {
    this.dialogTarget.close()
  }

  // Clicking the backdrop lands on the dialog element itself; a click anywhere
  // inside lands on a child.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
