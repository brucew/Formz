import { Controller } from "@hotwired/stimulus"

// Adds and removes field rows in the form editor.
//
// New rows are cloned from a <template> whose input names carry a NEW_RECORD placeholder,
// swapped for a child index that is unique on the page. Removing a row that has already
// been saved checks its hidden _destroy input and hides the row, so the server is told to
// destroy it; an unsaved row is simply dropped.
export default class extends Controller {
  static targets = ["template", "rows", "row"]

  add(event) {
    event.preventDefault()

    const row = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.nextChildIndex())
    this.rowsTarget.insertAdjacentHTML("beforeend", row)
  }

  remove(event) {
    event.preventDefault()

    const row = event.currentTarget.closest("[data-nested-fields-target='row']")
    if (!row) return

    const destroyInput = row.querySelector("input[name$='[_destroy]']")

    if (this.isPersisted(row) && destroyInput) {
      destroyInput.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }

  isPersisted(row) {
    return row.querySelector("input[name$='[id]']") !== null
  }

  nextChildIndex() {
    this.childIndex = (this.childIndex || Date.now()) + 1
    return this.childIndex
  }
}
