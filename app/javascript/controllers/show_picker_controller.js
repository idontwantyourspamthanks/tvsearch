import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "trigger", "menu", "backdrop", "emoji", "name", "option"]
  static values = { open: Boolean }

  connect() {
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    this.boundKeydown = this.handleKeydown.bind(this)
    this.forceClosedState()
    this.syncSelection(this.inputTarget.value)
  }

  disconnect() {
    this.removeListeners()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue ? this.close() : this.open()
  }

  open() {
    if (this.openValue) return
    this.openValue = true
    this.menuTarget.hidden = false
    this.backdropTarget.hidden = false
    this.element.classList.add("is-open")
    document.addEventListener("click", this.boundOutsideClick)
    document.addEventListener("keydown", this.boundKeydown)
  }

  close() {
    if (!this.openValue) return
    this.openValue = false
    this.menuTarget.hidden = true
    this.backdropTarget.hidden = true
    this.element.classList.remove("is-open")
    this.removeListeners()
  }

  select(event) {
    event.preventDefault()
    const button = event.currentTarget
    const selectedId = button.dataset.id || ""

    this.inputTarget.value = selectedId
    this.updateTrigger(button.dataset.emoji, button.dataset.name)
    this.markSelected(selectedId)
    this.close()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncSelection(showId) {
    const match = this.optionTargets.find(
      (button) => (button.dataset.id || "") === (showId || "")
    )

    if (match) {
      this.updateTrigger(match.dataset.emoji, match.dataset.name)
      this.markSelected(showId)
    }
  }

  updateTrigger(emoji, name) {
    this.emojiTarget.textContent = emoji || "✳️"
    const label = name || "All shows"
    this.nameTarget.textContent = label
    this.triggerTarget.setAttribute("aria-label", `Show filter: ${label}`)
  }

  markSelected(showId) {
    this.optionTargets.forEach((button) => {
      const selected = (button.dataset.id || "") === (showId || "")
      button.classList.toggle("is-selected", selected)
      button.setAttribute("aria-pressed", selected)
    })
  }

  handleOutsideClick(event) {
    const clickedBackdrop =
      this.backdropTarget && this.backdropTarget.contains(event.target)
    const insideMenuOrTrigger =
      this.menuTarget.contains(event.target) || this.triggerTarget.contains(event.target)

    if (!insideMenuOrTrigger || clickedBackdrop) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  removeListeners() {
    document.removeEventListener("click", this.boundOutsideClick)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  forceClosedState() {
    this.openValue = false
    this.menuTarget.hidden = true
    this.backdropTarget.hidden = true
    this.element.classList.remove("is-open")
    this.removeListeners()
  }
}
