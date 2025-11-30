require "json"
require "net/http"

module Voice
  class WhisperClient
    class Error < StandardError; end
    class ConfigurationError < Error; end

    API_URL = URI("https://api.openai.com/v1/audio/transcriptions").freeze
    MODEL = "whisper-1".freeze

    def initialize(api_key: ENV["OPENAI_KEY"])
      @api_key = api_key
      raise ConfigurationError, "OPENAI_KEY is missing" if @api_key.blank?
    end

    def transcribe(upload)
      raise Error, "No audio file provided" unless upload

      file = extract_file(upload)
      request = Net::HTTP::Post.new(API_URL)
      request["Authorization"] = "Bearer #{@api_key}"
      request.set_form(form_data(file), "multipart/form-data")

      response = http_client.request(request)
      parsed = parse_json(response)

      if response.code.to_i >= 400
        message = parsed.dig("error", "message") || parsed["error"] || response.body
        raise Error, "OpenAI error (#{response.code}): #{message}"
      end

      transcript = parsed["text"].to_s.strip
      raise Error, "Empty transcript returned" if transcript.blank?

      transcript
    rescue JSON::ParserError
      raise Error, "Unexpected response from OpenAI (#{response.code})"
    end

    private

    def extract_file(upload)
      tempfile = upload.respond_to?(:tempfile) ? upload.tempfile : upload
      filename = upload.respond_to?(:original_filename) ? upload.original_filename.presence : nil
      content_type = upload.respond_to?(:content_type) ? upload.content_type.presence : nil

      raise Error, "Audio upload is missing" unless tempfile

      tempfile.binmode
      tempfile.rewind

      {
        io: tempfile,
        filename: filename || default_filename(content_type),
        content_type: content_type || "audio/webm"
      }
    end

    def default_filename(content_type)
      extension = content_type&.split("/")&.last || "webm"
      "voice-search.#{extension}"
    end

    def form_data(file)
      [
        ["model", MODEL],
        ["file", file[:io], { filename: file[:filename], content_type: file[:content_type] }],
        ["response_format", "json"]
      ]
    end

    def http_client
      @http_client ||= begin
        http = Net::HTTP.new(API_URL.host, API_URL.port)
        http.use_ssl = API_URL.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 45
        http
      end
    end

    def parse_json(response)
      JSON.parse(response.body)
    end
  end
end
