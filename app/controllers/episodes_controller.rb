class EpisodesController < ApplicationController
  before_action :require_admin!, only: :refresh_image
  before_action :set_episode, only: %i[show refresh_image]

  def index
    @query = params[:q].to_s.strip
    @show_id = params[:show_id].presence
    scope = Episode.search(@query).by_show_episode
    scope = scope.where(show_id: @show_id) if @show_id
    @episodes = scope
    @shows = Show.order(:name)
  end

  def show
  end

  def refresh_image
    if @episode.image_url.blank?
      return render json: { error: "Episode has no image URL to fetch." }, status: :unprocessable_entity
    end

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
end
