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
   - POST `/admin/tvdb_import` with `series_id` (and `query` for redirect context) from the search results table.
3. **Import (single request)**: Controller performs the import synchronously.
   - Fetch show metadata via `Tvdb::Client#series_details` (`GET /series/<id>`).
   - Fetch all episodes via `Tvdb::Client#episodes_for_series`, which internally walks pages of `GET /series/<id>/episodes/default?page=<n>` using `links.next` until exhausted.
   - Show is `find_or_create_by` name; description set on create only.
   - For each episode: map attributes (`name`/`episodeName`/`translations.eng.name`, `seasonNumber`/`airedSeason`, `number`/`episodeNumber`/`airedEpisodeNumber`, `overview`/`description`/`translations.eng.overview`, `aired`), find-or-initialize by show + title, assign, save. No progress UI; full import happens in one server request.

### Error handling
- Any 4xx/5xx from TVDB raises `Tvdb::Client::Error` with TVDB’s `status` message.
- JSON parse errors raise `Unexpected response format`.

### Key files
- TVDB client: `app/services/tvdb/client.rb`
- Admin controller: `app/controllers/admin/tvdb_imports_controller.rb`
- Admin search/import page: `app/views/admin/tvdb_imports/new.html.erb`
