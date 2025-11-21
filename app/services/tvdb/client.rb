require "net/http"
require "json"

module Tvdb
  class Client
    class Error < StandardError; end

    BASE_URL = "https://api4.thetvdb.com/v4".freeze

    def initialize(api_key: ENV["TVDB_API_KEY"])
      @api_key = api_key
      raise Error, "TVDB_API_KEY is missing" unless @api_key.present?
    end

    def search_series(query)
      response = get("/search", { q: query, type: "series" })
      response["data"] || []
    end

    def series_details(series_id)
      response = get("/series/#{series_id}")
      response["data"] || {}
    end

    def series_seasons(series_id)
      response = get("/series/#{series_id}/extended")
      seasons_data = response.dig("data", "seasons") || []

      # Filter to only aired order seasons and exclude "all seasons" type
      seasons_data.select { |s| s.dig("type", "name")&.downcase&.include?("aired") }
                  .reject { |s| s.dig("type", "name") == "All Seasons" }
                  .map do |season|
        # Get detailed season information
        season_details = season_extended(season["id"]) if season["id"]

        # Extract name - try nameTranslations array lookup, then fallback
        season_name = extract_translation(season_details, "name") ||
                     extract_translation(season, "name") ||
                     "Season #{season['number']}"

        # Remove the type suffix if it's just duplicating info
        type_name = season.dig("type", "name")
        season_name = season_name.gsub(/\s*\(#{Regexp.escape(type_name)}\)\s*$/i, "") if type_name

        # Try to extract episode count from the episodes array if present
        episodes = season_details&.dig("episodes") || []
        episode_count = episodes.size if episodes.any?

        # Try to extract air date range from episodes
        aired_dates = episodes.map { |ep| ep["aired"] }.compact.map { |d| Date.parse(d) rescue nil }.compact.sort
        first_aired = aired_dates.first&.strftime("%B %Y")
        last_aired = aired_dates.last&.strftime("%B %Y")

        {
          id: season["id"],
          number: season["number"],
          name: season_name,
          type: type_name,
          year: season_details&.dig("year"),
          first_aired: first_aired,
          last_aired: last_aired,
          episode_count: episode_count
        }
      end.sort_by { |s| s[:number].to_i }
    rescue Error => e
      Rails.logger.error "Error fetching seasons for series #{series_id}: #{e.message}"
      []
    end

    def season_extended(season_id)
      response = get("/seasons/#{season_id}/extended")
      data = response["data"]

      # Log what fields are actually available
      if data
        Rails.logger.debug "Season #{season_id} extended keys: #{data.keys.join(', ')}"
        Rails.logger.debug "Season #{season_id} extended sample: #{data.slice('id', 'number', 'name', 'year', 'episodes').inspect}"
      end

      data
    rescue Error => e
      Rails.logger.warn "Could not fetch extended info for season #{season_id}: #{e.message}"
      nil
    end

    def episodes_for_series(series_id)
      page = 0
      episodes = []

      loop do
        response = episodes_page(series_id, page: page)
        data = response[:episodes]
        break if data.empty?

        episodes.concat(data)

        next_page = response[:next_page]
        break unless next_page

        page = next_page
      end

      episodes
    end

    def episodes_page(series_id, page: 0)
      response = get("/series/#{series_id}/episodes/default", { page: page })
      {
        episodes: extract_episodes(response),
        next_page: parse_next_page(response["links"]),
        total_pages: total_pages_from_links(response["links"])
      }
    end

    private

    attr_reader :api_key

    def extract_translation(data, field)
      return nil unless data.is_a?(Hash)

      # Try direct field access first
      direct_value = data[field]
      return direct_value if direct_value.present?

      # Try translations - nameTranslations or overviewTranslations
      translations_key = "#{field}Translations"
      translations = data[translations_key]
      return nil unless translations.is_a?(Hash)

      # Try English first, then any available language
      translations["eng"] || translations["en"] || translations.values.first
    end

    def token
      Rails.cache.fetch("tvdb_token", expires_in: 20.minutes) do
        response = post("/login", { apikey: api_key })
        response.dig("data", "token") || raise(Error, "Missing token from TVDB")
      end
    end

    def get(path, params = {})
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) if params.present?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"

      perform_request(uri, request)
    end

    def post(path, body = {})
      uri = URI("#{BASE_URL}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      perform_request(uri, request)
    end

    def perform_request(uri, request)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      parsed = JSON.parse(response.body)
      raise Error, parsed["status"].to_s if response.code.to_i >= 400

      parsed
    rescue JSON::ParserError => e
      raise Error, "Unexpected response format: #{e.message}"
    end

    def extract_episodes(response)
      data = response["data"]
      return data["episodes"] if data.is_a?(Hash) && data["episodes"].is_a?(Array)
      return data if data.is_a?(Array)

      []
    end

    def total_pages_from_links(links)
      return unless links.is_a?(Hash)

      last_page = links["last"]
      return unless last_page

      first_page = links["first"] || 0
      first_value = first_page.to_i
      last_value = last_page.to_i
      (last_value - first_value) + 1
    end

    def parse_next_page(links)
      return nil unless links.is_a?(Hash)

      next_link = links["next"]
      return nil if next_link.nil?

      # If it's already an integer, return it
      return next_link if next_link.is_a?(Integer)

      # If it's a string that looks like a number, parse it
      if next_link.is_a?(String)
        # Try parsing as integer first
        page_num = next_link.to_i
        return page_num if page_num.to_s == next_link

        # Otherwise try to extract page parameter from URL
        uri = URI.parse(next_link) rescue nil
        if uri&.query
          params = URI.decode_www_form(uri.query).to_h
          return params["page"].to_i if params["page"]
        end
      end

      # If we can't parse it, return nil to stop pagination
      nil
    end
  end
end
