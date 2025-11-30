import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "status"]
  static values = {
    endpoint: String,
    maxDuration: { type: Number, default: 12 }
  }

  connect() {
    this.chunks = []
    this.isRecording = false
    this.isBusy = false
    this.supported =
      Boolean(navigator.mediaDevices?.getUserMedia) &&
      typeof window.MediaRecorder !== "undefined"

    if (!this.supported) {
      this.disable("Voice search needs a microphone and a modern browser.")
      return
    }

    this.setButtonState()
    this.setStatus("Tap the mic and speak — we'll fill in your search.")
  }

  disconnect() {
    this.stopRecording()
    this.stopStream()
    this.clearTimers()
  }

  async toggle(event) {
    event.preventDefault()
    if (!this.supported || this.isBusy) return

    if (this.isRecording) {
      this.stopRecording()
    } else {
      await this.startRecording()
    }
  }

  async startRecording() {
    this.clearTimers()
    this.chunks = []

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      this.fail("Microphone access was blocked. Check your browser permissions.")
      return
    }

    const options = {}
    const preferred = this.preferredMimeType()
    if (preferred) options.mimeType = preferred

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, options)
    } catch (error) {
      this.stopStream()
      this.fail("Voice recording isn't supported in this browser.")
      return
    }

    this.mediaRecorder.addEventListener("dataavailable", (event) => {
      if (event.data?.size > 0) this.chunks.push(event.data)
    })
    this.mediaRecorder.addEventListener("stop", () => this.handleStop())

    this.mediaRecorder.start()
    this.isRecording = true
    this.setButtonState({ recording: true })
    this.setStatus("Listening… tap again when you're done.", "active")
    this.recordingTimer = setTimeout(
      () => this.stopRecording(),
      this.maxDurationValue * 1000
    )
  }

  stopRecording() {
    this.clearTimers()
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop()
      this.isRecording = false
      this.setButtonState({ busy: true })
    } else {
      this.setButtonState()
    }
  }

  async handleStop() {
    this.stopStream()

    if (!this.chunks || this.chunks.length === 0) {
      this.isBusy = false
      this.setButtonState()
      this.setStatus("Didn't catch that. Try again a little louder.", "muted")
      return
    }

    const mimeType = this.mediaRecorder?.mimeType || "audio/webm"
    const blob = new Blob(this.chunks, { type: mimeType })
    this.chunks = []
    this.mediaRecorder = null

    await this.sendAudio(blob)
  }

  async sendAudio(blob) {
    this.isBusy = true
    this.setStatus("Transcribing with Whisper…", "active")
    this.setButtonState({ busy: true })

    const formData = new FormData()
    const extension = this.extensionFromMime(blob.type)
    formData.append("audio", blob, `voice-search.${extension}`)

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const headers = token ? { "X-CSRF-Token": token } : {}

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers,
        body: formData
      })
      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || "Something went wrong while transcribing.")
      }

      const transcript = (data.transcript || "").trim()
      if (transcript.length === 0) {
        throw new Error("We didn't get any text back. Please try again.")
      }

      this.applyTranscript(transcript)
      this.setStatus(`Filled from voice: “${this.truncate(transcript)}”`, "success")
    } catch (error) {
      this.fail(error.message)
    } finally {
      this.isBusy = false
      this.setButtonState()
    }
  }

  applyTranscript(transcript) {
    if (!this.hasInputTarget) return

    this.inputTarget.value = transcript
    this.inputTarget.focus()
    const end = transcript.length
    this.inputTarget.setSelectionRange(end, end)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  disable(message) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.title = message
      this.buttonTarget.classList.add("is-disabled")
      this.buttonTarget.setAttribute("aria-disabled", "true")
    }
    this.setStatus(message, "error")
  }

  fail(message) {
    this.isRecording = false
    this.isBusy = false
    this.stopStream()
    this.setButtonState()
    this.setStatus(message, "error")
  }

  stopStream() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop())
      this.stream = null
    }
  }

  clearTimers() {
    if (this.recordingTimer) {
      clearTimeout(this.recordingTimer)
      this.recordingTimer = null
    }
  }

  setButtonState({ recording = false, busy = false } = {}) {
    if (!this.hasButtonTarget) return
    this.isRecording = recording
    this.buttonTarget.classList.toggle("is-recording", recording)
    this.buttonTarget.classList.toggle("is-busy", busy)
    this.buttonTarget.disabled = busy
    this.buttonTarget.setAttribute("aria-pressed", recording ? "true" : "false")

    let label = "Start voice search"
    if (recording) label = "Stop recording"
    else if (busy) label = "Transcribing with Whisper"
    this.buttonTarget.setAttribute("aria-label", label)
  }

  setStatus(text, tone = "muted") {
    if (!this.hasStatusTarget) return
    if (!text) {
      this.statusTarget.hidden = true
      this.statusTarget.textContent = ""
      this.statusTarget.dataset.tone = ""
      return
    }

    this.statusTarget.hidden = false
    this.statusTarget.textContent = text
    this.statusTarget.dataset.tone = tone
  }

  preferredMimeType() {
    if (typeof MediaRecorder === "undefined" || !MediaRecorder.isTypeSupported) return null

    const candidates = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"]
    return candidates.find((type) => MediaRecorder.isTypeSupported(type)) || null
  }

  extensionFromMime(mime) {
    if (mime.includes("mp4")) return "mp4"
    if (mime.includes("ogg")) return "ogg"
    return "webm"
  }

  truncate(text, length = 80) {
    return text.length > length ? `${text.slice(0, length - 1)}…` : text
  }
}
