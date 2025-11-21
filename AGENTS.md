This is a Rails/Hotwire application. It fetches TV episode data from TVDB (see https://thetvdb.github.io/v4-api for details) and uses that to populate an internal database - we can then add extra information to this.

You will update this documentation as you make changes to things.

## TVDB Import Flow

This documents how we fetch and import data from TVDB so future changes are easier.

### Authentication
- Requires `TVDB_API_KEY` env var.
- POST `https://api4.thetvdb.com/v4/login` with JSON `{ "apikey": "<key>" }`.
- Expect JSON body with `data.token`; we cache the token in Rails cache for 20 minutes under `tvdb_token`.
- All subsequent requests set header `Authorization: Bearer <token>`.

### Admin workflow
1. **Search**: Admin visits `/admin/tvdb_import` and submits a query.
   - Controller calls `Tvdb::Client#search_series`.
   - GET `/search?q=<query>&type=series`; response has `data` array of series hashes (`id`/`tvdb_id`, `name`, `overview`, etc.).
2. **Select series**: Admin clicks “Import episodes”.
   - Controller calls `Tvdb::Client#series_details` for display.
   - GET `/series/<series_id>`; response `data` contains `name`/`seriesName`, `overview`/`description`.
   - Page shows summary and bootstraps the Stimulus controller with `series_id`, `show_name`, `show_description`, and the batch endpoint.
3. **Batch import episodes**: Stimulus controller posts batches until TVDB says there is no next page.
   - Endpoint: POST `/admin/tvdb_import/batch` with JSON `{ series_id, page, show_name, show_description, query }`.
   - Controller calls `Tvdb::Client#episodes_page(series_id, page: page)`.
     - GET `/series/<series_id>/episodes/default?page=<page>`.
     - Response body uses either `data: [...]` or `data: { episodes: [...] }`.
     - Pagination info comes from `links` (`next`, `last`, `first`); we return `next_page` (integer or `nil`) and `total_pages`.
   - Import logic maps each episode hash to attributes: `tvdb_id` (`id`), `name`/`episodeName`/`translations.eng.name`, `seasonNumber`/`airedSeason`, `number`/`episodeNumber`/`airedEpisodeNumber`, `overview`/`description`/`translations.eng.overview`, `aired`.
   - Shows now store `tvdb_id`; lookup prefers `tvdb_id`, then name. Episodes likewise try `tvdb_id`, then season/episode, then title.
   - For existing episodes we only fill blank fields (including `tvdb_id`) so user edits are preserved; show description is only set if blank.
   - Batch response JSON: `{ page, next_page, total_pages, created, updated, unchanged, skipped, entries: [{ title, season_number, episode_number, aired_on, status }] }`.
   - Stimulus updates the progress bar and counter text and stops when `next_page` is `null`.

### Error handling
- Any 4xx/5xx from TVDB raises `Tvdb::Client::Error` with TVDB’s `status` message.
- JSON parse errors raise `Unexpected response format`.
- Batch endpoint returns `{ error: message }` with 502 if TVDB fails; Stimulus shows “Import failed” and surfaces the message.

### Key files
- TVDB client: `app/services/tvdb/client.rb`
- Admin controller: `app/controllers/admin/tvdb_imports_controller.rb`
- Stimulus loop handling batches: `app/javascript/controllers/tvdb_import_controller.js`
