class VoiceResponsesController < ApplicationController
  protect_from_forgery with: :exception

  def create
    message = params[:message].to_s.strip
    if message.blank?
      render json: { error: "Message is required" }, status: :unprocessable_entity
      return
    end

    client = Voice::ElevenLabsClient.new
    audio = client.speak(message)

    send_data audio, type: "audio/mpeg", disposition: "inline"
  rescue Voice::ElevenLabsClient::ConfigurationError => e
    Rails.logger.warn("Voice response configuration missing: #{e.message}")
    render json: { error: "Voice response is not configured. #{e.message}" }, status: :service_unavailable
  rescue Voice::ElevenLabsClient::Error => e
    Rails.logger.warn("Voice response failed: #{e.message}")
    render json: { error: e.message }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("Voice response exception: #{e.class}: #{e.message}")
    render json: { error: "Unable to generate audio right now." }, status: :bad_gateway
  end
end
