import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "metadataStatus",
    "metadataDetail",
    "seasonsStatus",
    "seasonsContainer",
    "continueButton",
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
    this.seasons = []  // Store available seasons
    this.selectedSeasons = []  // Store selected season numbers
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
    this.seasonsStatusTarget.textContent = "Waiting for metadata…"
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
      this.seasons = data.seasons || []

      this.metadataStatusTarget.textContent = `Done · ${data.show_name}`
      if (data.show_description) {
        this.metadataDetailTarget.textContent = data.show_description
      }

      // Display seasons for selection
      this.displaySeasons()
    } catch (error) {
      this.metadataStatusTarget.textContent = "Failed to fetch metadata"
      this.metadataDetailTarget.textContent = ""
      this.seasonsStatusTarget.textContent = "Failed to fetch seasons"
      this.handleError(error)
    }
  }

  displaySeasons() {
    if (this.seasons.length === 0) {
      this.seasonsStatusTarget.textContent = "No seasons found"
      return
    }

    this.seasonsStatusTarget.textContent = `Found ${this.seasons.length} season${this.seasons.length !== 1 ? 's' : ''}`

    // Create check all/none buttons
    const buttonContainer = document.createElement("div")
    buttonContainer.style.marginBottom = "1rem"
    buttonContainer.style.display = "flex"
    buttonContainer.style.gap = "0.5rem"

    const checkAllBtn = document.createElement("button")
    checkAllBtn.type = "button"
    checkAllBtn.textContent = "Check All"
    checkAllBtn.className = "button small"
    checkAllBtn.addEventListener("click", () => this.toggleAllSeasons(true))

    const checkNoneBtn = document.createElement("button")
    checkNoneBtn.type = "button"
    checkNoneBtn.textContent = "Check None"
    checkNoneBtn.className = "button small"
    checkNoneBtn.addEventListener("click", () => this.toggleAllSeasons(false))

    buttonContainer.appendChild(checkAllBtn)
    buttonContainer.appendChild(checkNoneBtn)

    // Create checkbox list
    const form = document.createElement("div")
    form.className = "seasons-list"
    form.style.display = "flex"
    form.style.flexDirection = "column"
    form.style.gap = "0.5rem"

    this.seasons.forEach(season => {
      const label = document.createElement("label")
      label.style.display = "flex"
      label.style.alignItems = "center"
      label.style.gap = "0.5rem"
      label.style.cursor = "pointer"

      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.value = season.number
      checkbox.checked = true  // All checked by default
      checkbox.dataset.seasonNumber = season.number
      checkbox.className = "season-checkbox"

      const textContainer = document.createElement("div")
      textContainer.style.flex = "1"

      const nameSpan = document.createElement("strong")
      nameSpan.textContent = season.name
      // Don't show type if it's the default "Aired Order" or "Official"
      if (season.type && season.type !== "Official" && season.type !== "Aired Order") {
        nameSpan.textContent += ` (${season.type})`
      }

      textContainer.appendChild(nameSpan)

      // Add metadata (air dates and episode count)
      const metadata = this.formatSeasonMetadata(season)
      if (metadata) {
        const metaSpan = document.createElement("div")
        metaSpan.className = "muted small"
        metaSpan.textContent = metadata
        textContainer.appendChild(metaSpan)
      }

      label.appendChild(checkbox)
      label.appendChild(textContainer)
      form.appendChild(label)
    })

    this.seasonsContainerTarget.innerHTML = ""
    this.seasonsContainerTarget.appendChild(buttonContainer)
    this.seasonsContainerTarget.appendChild(form)
    this.continueButtonTarget.style.display = "inline-block"
  }

  formatSeasonMetadata(season) {
    const parts = []

    // Add year if available
    const year = season.year
    if (year) {
      parts.push(year.toString())
    }

    // Add episode count if available
    if (season.episode_count) {
      parts.push(`${season.episode_count} episodes`)
    }

    // Add air date range if available
    if (season.first_aired && season.last_aired) {
      parts.push(`${season.first_aired} - ${season.last_aired}`)
    } else if (season.first_aired) {
      parts.push(`From ${season.first_aired}`)
    }

    return parts.length > 0 ? parts.join(' · ') : null
  }

  toggleAllSeasons(checked) {
    const checkboxes = this.seasonsContainerTarget.querySelectorAll('.season-checkbox')
    checkboxes.forEach(checkbox => {
      checkbox.checked = checked
    })
  }

  startImport() {
    // Collect selected seasons
    const checkboxes = this.seasonsContainerTarget.querySelectorAll('input[type="checkbox"]:checked')
    this.selectedSeasons = Array.from(checkboxes).map(cb => parseInt(cb.value))

    if (this.selectedSeasons.length === 0) {
      alert("Please select at least one season to import")
      return
    }

    this.seasonsStatusTarget.textContent = `Importing ${this.selectedSeasons.length} season${this.selectedSeasons.length !== 1 ? 's' : ''}`
    this.continueButtonTarget.disabled = true
    this.episodesStatusTarget.textContent = "Starting import…"

    this.fetchNextBatch()
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
          query: this.queryValue,
          selected_seasons: this.selectedSeasons
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
