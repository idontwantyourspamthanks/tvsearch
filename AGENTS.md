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
2. **Select series**: Admin clicks "Import episodes".
   - POST `/admin/tvdb_import` with `series_id` to land on a progress page.
3. **Progress page (multi-step)**:
   - **Step 1: Metadata** — Stimulus controller calls `POST /admin/tvdb_import/details` with `{ series_id }`.
     - Server uses `Tvdb::Client#series_details` (`GET /series/<id>`) to get basic series info.
     - Server calls `Tvdb::Client#series_seasons` which:
       - Fetches `GET /series/<id>/extended` to get list of seasons.
       - Filters to only "Aired Order" seasons (excludes DVD Order, All Seasons, etc.).
       - For each season, calls `GET /seasons/<season_id>/extended` to get detailed info including `year` and `episodes` array.
       - Extracts episode count by counting the episodes array.
       - Calculates air date range (e.g., "October 1984 - January 1985") from first and last episode aired dates.
       - Uses `extract_translation` helper to get season names from nameTranslations hash (tries "eng", "en", or first available).
     - Returns `{ show_name, show_description, tvdb_id, seasons: [...] }` where each season includes `id`, `number`, `name`, `type`, `year`, `first_aired`, `last_aired`, `episode_count`.
   - **Step 2: Season selection** — UI displays all seasons with checkboxes (all checked by default).
     - Shows season metadata: year, episode count, and air date range when available.
     - Provides "Check All" / "Check None" buttons for convenience.
     - Admin clicks "Continue with selected seasons" to proceed.
   - **Step 3: Episodes** — Stimulus loops over pages via `POST /admin/tvdb_import/batch` with `{ series_id, page, show_name, show_description, query, selected_seasons }`.
     - Server calls `Tvdb::Client#episodes_page` (`GET /series/<id>/episodes/default?page=<page>`), which returns episodes + pagination.
     - Pagination uses `parse_next_page` to handle various `links.next` formats (integer, string number, or URL with query params).
     - Episodes are filtered to only include selected season numbers.
     - Show lookup prefers `tvdb_id`, then name. Episodes match by `tvdb_id`, then season/episode, then downcased title.
     - For existing episodes we only fill blank fields (including `tvdb_id`) to avoid overwriting edits; show description set only if blank.
     - Image handling: cache dir is `public/episode_images`. We now verify that any cached image actually exists and is non-empty before early return; if the file is missing/zero bytes we re-download. Episodes with a valid `image_url` but missing/bad cache are marked as updated once the image is refreshed.
     - Tracks reason for each status: created (lists interesting fields), updated (lists changed fields), unchanged ("No attribute changes"), skipped (validation errors or missing title) plus image download notes (cached/downloaded/failed) when relevant.
     - Response JSON includes per-page stats: `{ page, fetched, next_page, total_pages, created, updated, unchanged, skipped, entries[...] }` where `entries` contains **all** processed episodes with `image_action` (`downloaded`, `cached`, `failed`, or `none`).
     - Pagination stops when `next_page` is null/undefined or equals current page (prevents infinite loops).
   - **Step 4: Summary** — After `next_page` is `null`, UI shows totals and detailed breakdown.
     - Groups episodes by status and reason (e.g., "15x Updated: title, description") and now calls out image refresh counts.
     - Displays last 24 entries in the Step 3 log with reasons shown in italics, and a full-width "Per-episode status" block listing **all** imported episodes and what happened to each (including image work).
     - Progress bar reflects page progress; counts show fetched totals and remaining pages.

### Pagination details
- The `parse_next_page` method handles different formats returned by TVDB API:
  - Integer: returns as-is
  - String number (e.g., "1"): parses to integer
  - URL with query params: extracts `page` parameter
  - Invalid/unparseable: returns nil to stop pagination
- Pagination loop checks `next_page !== data.page` to prevent infinite loops where API returns same page number.
- Frontend Stimulus value `nextPage` has no type constraint (was causing NaN issues when null was converted to Number type).
- `total_pages` calculated from `links.last - links.first + 1` when available.

### Episode validation
- Episodes require a `title` (will be skipped if missing).
- `season_number` and `episode_number` allow nil and must be >= 0 (to support season 0 for specials).
- `tvdb_id` must be unique if present.

### Error handling
- Any 4xx/5xx from TVDB raises `Tvdb::Client::Error` with TVDB's `status` message.
- JSON parsing now retries after forcing UTF-8/replacing bad bytes and raises `Unexpected response format (url, status ...): ... — body: <snippet>` with a body preview for debugging.
- `/details` and `/batch` return `{ error, error_class, detail }` (and page context for batch) with HTTP 502; UI surfaces the full message and stops.
- Failed season extended fetches log warnings but don't stop the import (season shown without extended data).
- Manual episode image refresh (admin-only button on homepage episode cards) posts to `/episodes/:id/refresh_image`; if `image_url` is blank but `tvdb_id` is present it fetches episode details from TVDB, populates `image_url`, and force-downloads the image.
- `require_admin!` now returns JSON `{ error }` + 401 for JSON requests (e.g., the manual image refresh) instead of HTML redirects, to avoid JSON parse errors in fetch clients when sessions expire.
- `refresh_image` returns early after rendering errors to avoid double-render exceptions.

### Episode search
- All search matches normalize accents using character replacements plus `I18n.transliterate`, so "cafe" will match "café" in titles/descriptions/alternate titles/show names.
- When `q` is blank, episodes are ordered by show name, then season, then episode, then air date.
- When `show_id` is present (with or without `q`), results keep the series/season/episode ordering.
- When `q` is present without a selected show, ordering switches to a relevance score that prefers matches in title, then alternate titles, then description, with show/season/episode as tie-breakers.
- UI highlighting of matches is also accent-insensitive so "cafe" highlights "café" in titles, alternate titles, and descriptions.
- Homepage show filter uses an emoji picker (Stimulus `show_picker_controller.js`) instead of a native select: the trigger shows ✳️ when no show is picked and the show emoji otherwise. Desktop opens a dropdown; mobile opens a fullscreen sheet with a backdrop. Selecting a show updates the hidden `show_id` field and dispatches input/change events so the live search Turbo frame refreshes immediately.
- Picker menu/backdrop respect the `hidden` attribute with explicit CSS so they start closed and can be dismissed by clicking outside/escape.
- Seed data now includes emoji values for sample shows (e.g., The Office 🏢, Breaking Bad 🧪, Stranger Things 👾, Succession 💼, The Mandalorian 🛸) and populates them for existing records missing emojis.

### Voice search
- Requires `OPENAI_KEY` env var (falls back to `OPENAI_API_KEY` or Rails credentials `openai.api_key`) to call OpenAI Whisper; stored as Kamal secret.
- POST `/voice_search` with multipart `audio` upload; responds with `{ transcript }`, 503 if the key is missing, and 502 when transcription fails.
- `Voice::WhisperClient` (Net::HTTP) sends audio to `https://api.openai.com/v1/audio/transcriptions` with `model: whisper-1`, 10s open timeout, 45s read timeout, and raises descriptive errors.
- Homepage search form runs Stimulus `voice_search_controller.js`: mic button records via MediaRecorder (up to 12s), shows listening/transcribing/error states, and drops the transcript into the `q` field while dispatching input/change events so live search submits automatically. On desktop the mic button sits between the query box and show picker; on mobile it stacks above the inputs to avoid overflow.

### Key files
- TVDB client: `app/services/tvdb/client.rb`
- Admin controller: `app/controllers/admin/tvdb_imports_controller.rb`
- Admin search/import page: `app/views/admin/tvdb_imports/new.html.erb`
- Progress page + Stimulus: `app/views/admin/tvdb_imports/create.html.erb`, `app/javascript/controllers/tvdb_import_controller.js`
- Voice search: `app/controllers/voice_searches_controller.rb`, `app/services/voice/whisper_client.rb`, `app/javascript/controllers/voice_search_controller.js`
- Deploy: `config/deploy.yml` mounts `tv_storage:/rails/storage` and `tv_episode_images:/rails/public/episode_images` so episode image cache persists across releases.
