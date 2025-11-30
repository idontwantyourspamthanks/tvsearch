class VoiceSearchesController < ApplicationController
  def create
    audio = params[:audio]
    if audio.blank?
      render json: { error: "No audio provided" }, status: :unprocessable_entity
      return
    end

    client = Voice::WhisperClient.new
    transcript = client.transcribe(audio)

    render json: { transcript: transcript }
  rescue Voice::WhisperClient::ConfigurationError => e
    Rails.logger.warn("Voice search configuration missing: #{e.message}")
    render json: { error: "Voice search is not configured. #{e.message}" }, status: :service_unavailable
  rescue Voice::WhisperClient::Error => e
    Rails.logger.warn("Voice search failed: #{e.message}")
    render json: { error: e.message }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("Voice search exception: #{e.class}: #{e.message}")
    render json: { error: "Unable to process that audio right now." }, status: :bad_gateway
  end
end
