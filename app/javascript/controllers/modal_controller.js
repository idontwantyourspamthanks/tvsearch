import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  close(event) {
    event?.preventDefault()
    const modal = document.getElementById("modal")
    if (modal) modal.innerHTML = ""
  }

  stop(event) {
    event.stopPropagation()
  }

  closeWithEscape(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }
}
