import { Controller } from "@hotwired/stimulus"

// Automatically submit the search form after the user stops typing.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  disconnect() {
    this.clearTimer()
  }

  connect() {
    this.submittedOnConnect = false
    if (this.shouldSubmitOnConnect()) {
      this.element.requestSubmit()
      this.submittedOnConnect = true
    }
  }

  queue() {
    this.clearTimer()
    this.timer = setTimeout(() => {
      // requestSubmit preserves Turbo/Remote behavior
      this.element.requestSubmit()
    }, this.delayValue)
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  shouldSubmitOnConnect() {
    if (this.submittedOnConnect) return false

    const queryField = this.element.querySelector('input[name="q"]')
    const showSelect = this.element.querySelector('select[name="show_id"]')

    const hasQuery = queryField && queryField.value.trim().length > 0
    const hasShowFilter = showSelect && showSelect.value && showSelect.value.trim().length > 0

    return hasQuery || hasShowFilter
  }
}
