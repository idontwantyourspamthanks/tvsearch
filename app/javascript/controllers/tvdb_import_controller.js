import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "metadataStatus",
    "metadataDetail",
    "episodesStatus",
    "episodesCounts",
    "progressBar",
    "log",
    "summaryStatus",
    "summaryCounts",
    "errorBox",
    "errorMessage"
  ]

  static values = {
    seriesId: String,
    query: String,
    detailsUrl: String,
    batchUrl: String,
    showName: String,
    showDescription: String,
    nextPage: { default: 0 },  // No type constraint - needs to handle both numbers and null
    totalPages: Number,
    pagesProcessed: { type: Number, default: 0 },
    created: { type: Number, default: 0 },
    updated: { type: Number, default: 0 },
    unchanged: { type: Number, default: 0 },
    skipped: { type: Number, default: 0 },
    fetched: { type: Number, default: 0 }
  }

  connect() {
    this.allResults = []  // Store all episode results for final summary
    this.fetchMetadata()
  }

  get headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": token
    }
  }

  async fetchMetadata() {
    this.metadataStatusTarget.textContent = "Fetching metadata…"
    this.metadataDetailTarget.textContent = ""
    this.clearError()

    try {
      const response = await fetch(this.detailsUrlValue, {
        method: "POST",
        headers: this.headers,
        body: JSON.stringify({ series_id: this.seriesIdValue })
      })

      const data = await response.json()
      if (!response.ok || data.error) {
        throw new Error(this.formatError(data.error, data.error_class, { detail: data.detail }))
      }

      this.showNameValue = data.show_name
      this.showDescriptionValue = data.show_description

      this.metadataStatusTarget.textContent = `Done · ${data.show_name}`
      if (data.show_description) {
        this.metadataDetailTarget.textContent = data.show_description
      }

      this.episodesStatusTarget.textContent = "Starting import…"
      this.fetchNextBatch()
    } catch (error) {
      this.metadataStatusTarget.textContent = "Failed to fetch metadata"
      this.metadataDetailTarget.textContent = ""
      this.handleError(error)
    }
  }

  async fetchNextBatch() {
    if (this.nextPageValue === null || this.nextPageValue === undefined) {
      this.finish()
      return
    }

    const page = this.nextPageValue

    // Sanity check: page should be a valid number
    if (typeof page !== 'number' || isNaN(page)) {
      const errorDetails = {
        page_value: page,
        page_type: typeof page,
        is_nan: isNaN(page),
        pages_processed: this.pagesProcessedValue,
        total_pages: this.totalPagesValue
      }
      console.error('Invalid page number detected:', errorDetails)
      this.handleError(new Error(`Invalid page number: ${JSON.stringify(errorDetails)}`))
      return
    }

    this.episodesStatusTarget.textContent = `Fetching page ${page + 1}…`
    this.clearError()

    try {
      const response = await fetch(this.batchUrlValue, {
        method: "POST",
        headers: this.headers,
        body: JSON.stringify({
          series_id: this.seriesIdValue,
          page,
          show_name: this.showNameValue,
          show_description: this.showDescriptionValue,
          query: this.queryValue
        })
      })

      const data = await response.json()
      if (!response.ok || data.error) {
        const message = this.formatError(data.error, data.error_class, {
          page,
          detail: data.detail
        })
        throw new Error(message)
      }

      this.handleBatch(data)
    } catch (error) {
      this.episodesStatusTarget.textContent = "Import failed"
      this.handleError(error)
    }
  }

  handleBatch(data) {
    this.pagesProcessedValue += 1
    this.totalPagesValue = data.total_pages || this.totalPagesValue

    // Check if there's a valid next page
    // next_page should be null/undefined when done, or a number > current page
    const hasNextPage = data.next_page !== null &&
                        data.next_page !== undefined &&
                        data.next_page !== data.page

    this.createdValue += data.created || 0
    this.updatedValue += data.updated || 0
    this.unchangedValue += data.unchanged || 0
    this.skippedValue += data.skipped || 0
    this.fetchedValue += data.fetched || 0

    // Store all entries for final summary
    if (data.entries && data.entries.length > 0) {
      this.allResults.push(...data.entries)
    }

    this.updateProgress(data)
    this.renderEntries(data.entries || [])

    // Decide whether to continue or finish
    if (!hasNextPage) {
      this.nextPageValue = null
      this.finish()
    } else {
      this.nextPageValue = data.next_page
      this.fetchNextBatch()
    }
  }

  updateProgress(data) {
    const total = this.totalPagesValue
    const percent = total ? Math.min(100, (this.pagesProcessedValue / total) * 100) : Math.min(95, 8 + this.pagesProcessedValue * 10)
    this.progressBarTarget.style.width = `${percent.toFixed(1)}%`

    const totalPagesLabel = total ? `of ${total}` : ""
    this.episodesStatusTarget.textContent = `Imported page ${data.page + 1} ${totalPagesLabel}`

    const remaining = total ? Math.max(0, total - this.pagesProcessedValue) : "?"
    this.episodesCountsTarget.textContent = `Fetched ${this.fetchedValue} total (+${data.fetched || 0} this page) · ${remaining} pages remaining`
  }

  renderEntries(entries) {
    if (!entries.length) return

    const placeholder = this.logTarget.querySelector("p")
    if (placeholder) placeholder.remove()

    const fragment = document.createDocumentFragment()
    entries.forEach((entry) => fragment.appendChild(this.buildLogRow(entry)))
    this.logTarget.prepend(fragment)

    const rows = Array.from(this.logTarget.querySelectorAll(".entry"))
    rows.slice(24).forEach((row) => row.remove())
  }

  buildLogRow(entry) {
    const row = document.createElement("div")
    row.className = "entry"

    const text = document.createElement("div")
    text.className = "entry-text"

    const title = document.createElement("strong")
    title.textContent = entry.title
    text.appendChild(title)

    const meta = document.createElement("div")
    meta.className = "muted small"
    meta.textContent = this.formatMeta(entry)
    text.appendChild(meta)

    // Add reason if present
    if (entry.reason) {
      const reason = document.createElement("div")
      reason.className = "muted small"
      reason.style.fontStyle = "italic"
      reason.textContent = entry.reason
      text.appendChild(reason)
    }

    row.appendChild(text)

    const badge = document.createElement("span")
    badge.className = `pill ${this.badgeClass(entry.status)}`
    badge.textContent = this.labelFor(entry.status)
    row.appendChild(badge)

    return row
  }

  formatMeta(entry) {
    const parts = []
    if (entry.season_number) parts.push(`S${entry.season_number}`)
    if (entry.episode_number) parts.push(`E${entry.episode_number}`)
    if (entry.aired_on) parts.push(`Aired ${entry.aired_on}`)
    return parts.join(" · ") || "TVDB"
  }

  badgeClass(status) {
    if (status === "created" || status === "updated") return "success"
    if (status === "error") return "error"
    if (status === "skipped") return "muted"
    return "muted"
  }

  labelFor(status) {
    if (status === "created") return "Created"
    if (status === "updated") return "Updated"
    if (status === "unchanged") return "Unchanged"
    if (status === "error") return "Error"
    return "Skipped"
  }

  finish() {
    this.progressBarTarget.style.width = "100%"
    this.episodesStatusTarget.textContent = `Import finished for ${this.showNameValue || "series"}`
    this.summaryStatusTarget.textContent = "Complete"

    const summaryParts = []
    if (this.createdValue > 0) summaryParts.push(`Created ${this.createdValue}`)
    if (this.updatedValue > 0) summaryParts.push(`Updated ${this.updatedValue}`)
    if (this.skippedValue > 0) summaryParts.push(`Skipped ${this.skippedValue}`)
    if (this.unchangedValue > 0) summaryParts.push(`Unchanged ${this.unchangedValue}`)

    this.summaryCountsTarget.textContent = summaryParts.join(" · ")

    // Show breakdown by status
    this.showDetailedBreakdown()
  }

  showDetailedBreakdown() {
    const skipped = this.allResults.filter(e => e.status === 'skipped')
    const unchanged = this.allResults.filter(e => e.status === 'unchanged')
    const updated = this.allResults.filter(e => e.status === 'updated')
    const created = this.allResults.filter(e => e.status === 'created')

    const breakdownLines = []

    if (created.length > 0) {
      breakdownLines.push(`\n✓ Created ${created.length} new episodes`)
    }

    if (updated.length > 0) {
      breakdownLines.push(`\n✓ Updated ${updated.length} episodes`)
      const reasons = this.groupByReason(updated)
      Object.entries(reasons).forEach(([reason, count]) => {
        breakdownLines.push(`  - ${count}x ${reason}`)
      })
    }

    if (unchanged.length > 0) {
      breakdownLines.push(`\n○ ${unchanged.length} episodes already up to date`)
    }

    if (skipped.length > 0) {
      breakdownLines.push(`\n⚠ Skipped ${skipped.length} episodes:`)
      const reasons = this.groupByReason(skipped)
      Object.entries(reasons).forEach(([reason, count]) => {
        breakdownLines.push(`  - ${count}x ${reason}`)
      })
    }

    if (breakdownLines.length > 0) {
      console.log('Import complete! Breakdown:', breakdownLines.join('\n'))

      // Add a visual breakdown to the summary
      const detailDiv = document.createElement('div')
      detailDiv.className = 'import-breakdown muted small'
      detailDiv.style.marginTop = '1rem'
      detailDiv.style.whiteSpace = 'pre-wrap'
      detailDiv.textContent = breakdownLines.join('\n')
      this.summaryCountsTarget.appendChild(document.createElement('br'))
      this.summaryCountsTarget.appendChild(detailDiv)
    }
  }

  groupByReason(episodes) {
    const grouped = {}
    episodes.forEach(ep => {
      const reason = ep.reason || 'No reason provided'
      grouped[reason] = (grouped[reason] || 0) + 1
    })
    return grouped
  }

  formatError(message, errorClass, context = {}) {
    const contextText = Object.keys(context).length ? ` (${JSON.stringify(context)})` : ""
    return [errorClass, message].filter(Boolean).join(": ") + contextText
  }

  handleError(error) {
    console.error('Import error:', error)
    this.errorBoxTarget.hidden = false

    // Show detailed error information
    let errorText = error.message || error.toString()
    if (error.stack) {
      errorText += '\n\nStack trace:\n' + error.stack
    }

    this.errorMessageTarget.textContent = errorText
    this.summaryStatusTarget.textContent = "Stopped due to error"
  }

  clearError() {
    if (!this.errorBoxTarget.hidden) {
      this.errorBoxTarget.hidden = true
      this.errorMessageTarget.textContent = ""
    }
  }
}
