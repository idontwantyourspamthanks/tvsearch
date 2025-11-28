import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.busted = false
    // If the controller is attached directly to the image element, set target manually
    if (!this.hasImageTarget && this.element.tagName === "IMG") {
      this.imageTarget = this.element
    }
  }

  retry() {
    if (this.busted) return
    if (!this.imageTarget) return

    this.busted = true
    const src = this.imageTarget.src
    const separator = src.includes("?") ? "&" : "?"
    const bustedSrc = `${src}${separator}bustCache=${Date.now()}`
    this.imageTarget.src = bustedSrc
  }
}
