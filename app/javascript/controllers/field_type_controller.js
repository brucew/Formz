import { Controller } from "@hotwired/stimulus"

// Shows the choices textarea only for the input types that are answered by picking from a
// list. It runs on connect as well as on change, so a saved choice-based field arrives
// with its choices already visible and a newly added row starts out correct.
export default class extends Controller {
  static targets = ["inputType", "choices", "choicesInput"]
  static values = { choiceBasedTypes: Array }

  connect() {
    this.showChoicesWhenNeeded()
  }

  inputTypeChanged() {
    this.showChoicesWhenNeeded()

    // Choices left behind by the previous input type would be rejected on save.
    if (this.choicesTarget.hidden) this.choicesInputTarget.value = ""
  }

  showChoicesWhenNeeded() {
    this.choicesTarget.hidden = !this.choiceBasedTypesValue.includes(this.inputTypeTarget.value)
  }
}
