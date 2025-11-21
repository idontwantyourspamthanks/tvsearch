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
   - POST `/admin/tvdb_import` with `series_id` to land on a progress page.
3. **Progress page (multi-step)**:
   - **Step 1: Metadata** — Stimulus controller calls `POST /admin/tvdb_import/details` with `{ series_id }`.
     - Server uses `Tvdb::Client#series_details` (`GET /series/<id>`) and returns `show_name`, `show_description`, and `tvdb_id`.
   - **Step 2: Episodes** — Stimulus loops over pages via `POST /admin/tvdb_import/batch` with `{ series_id, page, show_name, show_description, query }`.
     - Server calls `Tvdb::Client#episodes_page` (`GET /series/<id>/episodes/default?page=<page>`), which returns episodes + pagination (`links.next`, `links.last` for `total_pages`).
     - Show lookup prefers `tvdb_id`, then name. Episodes match by `tvdb_id`, then season/episode, then downcased title.
     - For existing episodes we only fill blank fields (including `tvdb_id`) to avoid overwriting edits; show description set only if blank.
     - Response JSON includes per-page stats: `{ page, fetched, next_page, total_pages, created, updated, unchanged, skipped, entries[...] }`.
   - **Step 3: Summary** — After `next_page` is `null`, UI shows totals and last few entries. Progress bar reflects page progress; counts show fetched totals and remaining pages.

### Error handling
- Any 4xx/5xx from TVDB raises `Tvdb::Client::Error` with TVDB’s `status` message.
- JSON parse errors raise `Unexpected response format`.
- `/details` and `/batch` return `{ error, error_class, detail }` (and page context for batch) with HTTP 502; UI surfaces the full message and stops.

### Key files
- TVDB client: `app/services/tvdb/client.rb`
- Admin controller: `app/controllers/admin/tvdb_imports_controller.rb`
- Admin search/import page: `app/views/admin/tvdb_imports/new.html.erb`
- Progress page + Stimulus: `app/views/admin/tvdb_imports/create.html.erb`, `app/javascript/controllers/tvdb_import_controller.js`
