class EpisodesController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @show_id = params[:show_id].presence
    scope = Episode.search(@query).recent_first
    scope = scope.where(show_id: @show_id) if @show_id
    @episodes = scope
    @shows = Show.order(:name)
  end

  def show
    @episode = Episode.find(params[:id])
  end
end
