import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "status", "counts", "log"]
  static values = {
    seriesId: String,
    showName: String,
    showDescription: String,
    nextPage: { type: Number, default: 0 },
    totalPages: Number,
    imported: { type: Number, default: 0 },
    updated: { type: Number, default: 0 },
    unchanged: { type: Number, default: 0 },
    skipped: { type: Number, default: 0 },
    query: String,
    batchUrl: String
  }

  connect() {
    this.running = true
    this.pagesProcessed = 0
    this.queueNextBatch()
  }

  disconnect() {
    this.running = false
    this.clearTimer()
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  queueNextBatch() {
    this.clearTimer()
    if (!this.running || this.nextPageValue === null) return
    this.timer = setTimeout(() => this.importNextBatch(), 80)
  }

  async importNextBatch() {
    if (!this.running || this.nextPageValue === null) return

    try {
      const response = await fetch(this.batchUrl, {
        method: "POST",
        headers: this.headers,
        body: JSON.stringify({
          series_id: this.seriesIdValue,
          page: this.nextPageValue,
          show_name: this.showNameValue,
          show_description: this.showDescriptionValue,
          query: this.queryValue
        })
      })

      const data = await response.json()
      if (!response.ok || data.error) {
        throw new Error(data.error || response.statusText)
      }

      this.handleBatch(data)
    } catch (error) {
      this.running = false
      this.statusTarget.textContent = "Import failed"
      this.countsTarget.textContent = error.message
      this.logTarget.prepend(this.buildLogRow({ title: error.message, status: "error" }))
    }
  }

  handleBatch(data) {
    this.pagesProcessed += 1
    this.totalPagesValue = data.total_pages || this.totalPagesValue
    this.importedValue += data.created || 0
    this.updatedValue += data.updated || 0
    this.unchangedValue += data.unchanged || 0
    this.skippedValue += data.skipped || 0

    const nextPage = data.next_page
    this.nextPageValue = nextPage === undefined || nextPage === null ? null : nextPage

    this.updateProgress()
    this.renderEntries(data.entries || [])

    if (this.nextPageValue === null) {
      this.finish()
    } else {
      this.queueNextBatch()
    }
  }

  updateProgress() {
    const total = this.totalPagesValue
    const percent = total ? Math.min(100, (this.pagesProcessed / total) * 100) : Math.min(95, 10 + this.pagesProcessed * 8)
    this.barTarget.style.width = `${percent.toFixed(1)}%`

    const pageLabel = total ? `Batch ${this.pagesProcessed} of ${total}` : `Batch ${this.pagesProcessed}`
    this.statusTarget.textContent = `${pageLabel} · ${this.showNameValue}`
    this.countsTarget.textContent = `Created ${this.importedValue} · Updated ${this.updatedValue} · Skipped ${this.skippedValue} · Unchanged ${this.unchangedValue}`
  }

  renderEntries(entries) {
    if (!entries.length) return

    const placeholder = this.logTarget.querySelector("p.muted.small")
    if (placeholder) placeholder.remove()

    const fragment = document.createDocumentFragment()
    entries.forEach((entry) => fragment.appendChild(this.buildLogRow(entry)))
    this.logTarget.prepend(fragment)
    this.trimLog()
  }

  buildLogRow(entry) {
    const row = document.createElement("div")
    row.className = "entry"

    const text = document.createElement("div")
    const title = document.createElement("strong")
    title.textContent = entry.title
    text.appendChild(title)

    const meta = document.createElement("div")
    meta.className = "muted small"
    meta.textContent = this.formatEpisodeCode(entry)
    text.appendChild(meta)

    row.appendChild(text)

    const badge = document.createElement("span")
    badge.className = `pill ${this.badgeClass(entry.status)}`
    badge.textContent = this.labelFor(entry.status)
    row.appendChild(badge)

    return row
  }

  trimLog() {
    const rows = Array.from(this.logTarget.querySelectorAll(".entry"))
    const maxRows = 14
    if (rows.length <= maxRows) return

    rows.slice(maxRows).forEach((row) => row.remove())
  }

  formatEpisodeCode(entry) {
    const parts = []
    if (entry.season_number) parts.push(`S${entry.season_number}`)
    if (entry.episode_number) parts.push(`E${entry.episode_number}`)
    const code = parts.join(" · ")

    if (entry.aired_on) return code ? `${code} · Aired ${entry.aired_on}` : `Aired ${entry.aired_on}`
    return code || "TVDB release"
  }

  labelFor(status) {
    if (status === "created") return "Created"
    if (status === "updated") return "Updated"
    if (status === "unchanged") return "Unchanged"
    if (status === "error") return "Error"
    return "Skipped"
  }

  badgeClass(status) {
    if (status === "created" || status === "updated") return "success"
    if (status === "error") return "error"
    if (status === "skipped") return "muted"
    return "muted"
  }

  finish() {
    this.barTarget.style.width = "100%"
    this.statusTarget.textContent = `Import finished for ${this.showNameValue}`
    this.countsTarget.textContent = `Created ${this.importedValue} · Updated ${this.updatedValue} · Skipped ${this.skippedValue} · Unchanged ${this.unchangedValue}`
  }

  get headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": token
    }
  }

  get batchUrl() {
    return this.hasBatchUrlValue ? this.batchUrlValue : "/admin/tvdb_import/batch"
  }
}
