import { Controller } from "@hotwired/stimulus"

// Automatically submit the search form after the user stops typing.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  disconnect() {
    this.clearTimer()
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
}
