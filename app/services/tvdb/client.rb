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

    def episodes_for_series(series_id)
      page = 0
      episodes = []

      loop do
        response = episodes_page(series_id, page:)
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
        next_page: response.dig("links", "next"),
        total_pages: total_pages_from_links(response["links"])
      }
    end

    private

    attr_reader :api_key

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
  end
end
