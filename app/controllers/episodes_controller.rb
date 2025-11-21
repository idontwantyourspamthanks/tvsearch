class EpisodesController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @episodes = Episode.search(@query).recent_first
  end

  def show
    @episode = Episode.find(params[:id])
  end
end
