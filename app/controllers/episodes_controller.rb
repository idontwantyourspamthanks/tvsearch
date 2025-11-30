class EpisodesController < ApplicationController
  before_action :require_admin!, only: :refresh_image
  before_action :set_episode, only: %i[show refresh_image]

  def index
    @query = params[:q].to_s.strip
    @show_id = params[:show_id].presence
    scope = Episode.search(@query)
    scope = scope.where(show_id: @show_id) if @show_id

    @episodes = if @query.present? && @show_id.blank?
      scope.order_by_relevance(@query)
    else
      scope.by_show_episode
    end
    @shows = Show.order(:name)
  end

  def show
  end

  def refresh_image
    return unless ensure_image_url!

    success = EpisodeImageDownloader.download(@episode, force: true)

    if success && EpisodeImageDownloader.cached_image_present?(@episode)
      render json: {
        image_url: @episode.display_image_url
      }
    else
      render json: { error: "Image download failed" }, status: :bad_gateway
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def set_episode
    @episode = Episode.find(params[:id])
  end

  def ensure_image_url!
    return true if @episode.image_url.present?

    if @episode.tvdb_id.present?
      client = Tvdb::Client.new
      data = client.episode_details(@episode.tvdb_id) || {}
      image_url = extract_image_url(data["data"] || data)
      if image_url.present?
        @episode.update_columns(image_url: image_url, image_path: nil)
        return true
      end
    end

    render json: { error: "Episode has no image URL to fetch." }, status: :unprocessable_entity
    false
  end

  def extract_image_url(data)
    image = data["image"]
    return nil if image.blank?

    return image if image.start_with?("http://", "https://")

    "https://artworks.thetvdb.com#{image}"
  end
end
