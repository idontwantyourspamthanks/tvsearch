require "json"
require "net/http"

module Voice
  class ElevenLabsClient
    class Error < StandardError; end
    class ConfigurationError < Error; end

    API_BASE = "https://api.elevenlabs.io/v1".freeze
    DEFAULT_VOICE_ID = "EXAVITQu4vr4xnSDxMaL".freeze # "Rachel" voice
    MODEL_ID = "eleven_multilingual_v2".freeze

    def initialize(api_key: nil, voice_id: DEFAULT_VOICE_ID)
      env_key = ENV["ELEVEN_KEY"].presence || ENV["ELEVENLABS_API_KEY"].presence
      creds_key = Rails.application.credentials.dig(:elevenlabs, :api_key) ||
                  Rails.application.credentials[:eleven_api_key] rescue nil

      @api_key = api_key.presence || env_key || creds_key.presence
      @voice_id = voice_id
      raise ConfigurationError, "ELEVEN_KEY/ELEVENLABS_API_KEY (or credentials elevenlabs.api_key) is missing" if @api_key.blank?
    end

    def speak(message)
      raise Error, "Message cannot be blank" if message.to_s.strip.empty?

      uri = URI("#{API_BASE}/text-to-speech/#{@voice_id}")
      request = Net::HTTP::Post.new(uri)
      request["xi-api-key"] = @api_key
      request["Accept"] = "audio/mpeg"
      request["Content-Type"] = "application/json"
      request.body = {
        text: message,
        model_id: MODEL_ID,
        voice_settings: { stability: 0.4, similarity_boost: 0.7 }
      }.to_json

      response = http_client.request(uri, request)
      raise Error, error_message(response) if response.code.to_i >= 400

      response.body
    end

    private

    def http_client
      @http_client ||= Net::HTTP
    end

    def error_message(response)
      parsed = JSON.parse(response.body) rescue nil
      detail = parsed && (parsed["detail"] || parsed["error"] || parsed["message"])
      "ElevenLabs error (#{response.code}): #{detail || response.body.to_s.truncate(200)}"
    end
  end
end
