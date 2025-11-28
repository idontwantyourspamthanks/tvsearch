import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.busted = false
  }

  retry() {
    if (this.busted) return
    const image = this.currentImage()
    if (!image) return

    this.busted = true
    const src = image.src
    const separator = src.includes("?") ? "&" : "?"
    const bustedSrc = `${src}${separator}bustCache=${Date.now()}`
    image.src = bustedSrc
  }

  currentImage() {
    if (this.hasImageTarget) return this.imageTarget
    if (this.element.tagName === "IMG") return this.element
    return null
  }
}
