import { Controller } from "@hotwired/stimulus"

// Submits the filter row as soon as a control changes, so the whole view
// re-renders against one slice. The form is a plain GET, so every slice stays
// linkable and the page still works with this controller absent.
export default class extends Controller {
  submit() {
    if (this.element.requestSubmit) {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
