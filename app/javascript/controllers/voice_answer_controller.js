import { Controller } from "@hotwired/stimulus"

const VOICE_FLAG_KEY = "voice-search:active"

// Plays a spoken summary of the first search result, but only after a voice search.
export default class extends Controller {
  static targets = ["episode"]
  static values = { endpoint: String }

  connect() {
    this.played = false
    this.maybeSpeak()
  }

  voiceSearchActive() {
    return window.sessionStorage.getItem(VOICE_FLAG_KEY) === "1"
  }

  clearVoiceFlag() {
    window.sessionStorage.removeItem(VOICE_FLAG_KEY)
  }

  handleFrameLoad() {
    this.played = false
    this.maybeSpeak()
  }

  maybeSpeak() {
    if (!this.voiceSearchActive()) return
    this.speakFirst()
  }

  async speakFirst() {
    if (this.played) return
    const episode = this.episodeTargets[0]
    if (!episode) return

    const message = this.buildMessage(episode.dataset)
    if (!message) {
      this.clearVoiceFlag()
      return
    }

    this.played = true
    try {
      const audioUrl = await this.fetchAudio(message)
      if (audioUrl) {
        const audio = new Audio(audioUrl)
        audio.play().catch(() => {})
      }
    } catch (error) {
      console.warn("Voice playback failed", error)
    } finally {
      this.clearVoiceFlag()
    }
  }

  buildMessage(data) {
    const title = data.voiceAnswerTitle
    if (!title) return null

    const altTitles = (data.voiceAnswerAlternateTitles || "")
      .split("|")
      .map((s) => s.trim())
      .filter(Boolean)
    const season = data.voiceAnswerSeasonNumber
    const episode = data.voiceAnswerEpisodeNumber

    let message = `It's called ${title}`
    if (altTitles.length > 0) {
      message += ` aka ${altTitles[0]}`
    }

    if (season || episode) {
      const seasonPart = season ? `season ${season}` : ""
      const episodePart = episode ? `episode ${episode}` : ""
      const connector = seasonPart && episodePart ? " " : ""
      message += ` and it's ${seasonPart}${connector}${episodePart}`.trim()
    }

    return message
  }

  async fetchAudio(message) {
    if (!this.hasEndpointValue) return null
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.endpointValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { "X-CSRF-Token": token } : {})
      },
      body: JSON.stringify({ message })
    })

    if (!response.ok) throw new Error("Audio request failed")
    const blob = await response.blob()
    return URL.createObjectURL(blob)
  }
}
