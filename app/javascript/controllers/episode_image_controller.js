import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "thumbnail", "status", "button"]
  static values = {
    refreshUrl: String,
    title: String
  }

  connect() {
    this.loading = false
    this.registerImageListeners()
    if (!this.hasImageTarget) {
      this.setStatus("No image cached")
      this.showButton()
    }
  }

  registerImageListeners() {
    if (!this.hasImageTarget) return

    this.imageTarget.addEventListener("error", () => this.handleError("Image failed to load"))
    this.imageTarget.addEventListener("load", () => this.clearStatus())
  }

  async refresh(event) {
    event.preventDefault()
    if (this.loading) return
    if (!this.refreshUrlValue) return

    this.loading = true
    this.disableButton(true)
    this.setStatus("Fetching image…")

    try {
      const response = await fetch(this.refreshUrlValue, {
        method: "POST",
        headers: this.headers
      })
      const data = await response.json()
      if (!response.ok || data.error) {
        throw new Error(data.error || "Failed to refresh image")
      }

      this.updateImage(data.image_url)
      this.setStatus("Image refreshed")
    } catch (error) {
      this.setStatus(error.message || "Failed to refresh image")
    } finally {
      this.disableButton(false)
      this.loading = false
    }
  }

  updateImage(url) {
    if (!url) return

    const bustedUrl = `${url}${url.includes("?") ? "&" : "?"}t=${Date.now()}`

    if (this.hasImageTarget) {
      this.imageTarget.src = bustedUrl
      this.imageTarget.removeAttribute("hidden")
      this.imageTarget.removeAttribute("aria-hidden")
    } else {
      const img = document.createElement("img")
      img.alt = this.titleValue || "Episode image"
      img.loading = "lazy"
      img.dataset.episodeImageTarget = "image"
      img.src = bustedUrl
      img.addEventListener("load", () => this.clearStatus())
      img.addEventListener("error", () => this.handleError("Image failed to load"))
      this.thumbnailTarget.appendChild(img)
    }
  }

  handleError(message) {
    if (this.hasImageTarget) {
      this.imageTarget.setAttribute("aria-hidden", "true")
    }
    this.setStatus(message || "Image failed to load")
    this.showButton()
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ""
    }
  }

  setStatus(text) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
    }
    this.showButton()
  }

  showButton() {
    if (this.hasButtonTarget) {
      this.buttonTarget.hidden = false
    }
  }

  disableButton(disabled) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = disabled
    }
  }

  get headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": token
    }
  }
}
