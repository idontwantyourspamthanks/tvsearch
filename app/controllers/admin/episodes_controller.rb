class Admin::EpisodesController < ApplicationController
  before_action :require_admin!
  before_action :set_episode, only: %i[edit update destroy]

  def index
    @query = params[:q].to_s.strip
    @show_id = params[:show_id].presence
    scope = Episode.search(@query).by_show_episode
    scope = scope.where(show_id: @show_id) if @show_id
    @episodes, @episodes_total, @current_page, @total_pages = paginate(scope)
    @shows = Show.order(:name)
  end

  def new
    @episode = Episode.new
  end

  def create
    @episode = Episode.new(episode_params)
    if @episode.save
      redirect_to admin_episodes_path, notice: "Episode created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @episode.update(episode_params)
      redirect_to admin_episodes_path, notice: "Episode updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to admin_episodes_path, notice: "Episode removed."
  end

  private

  def set_episode
    @episode = Episode.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:show_id, :title, :season_number, :episode_number, :description, :aired_on, :alternate_titles_text)
  end

  def paginate(scope)
    page = params.fetch(:page, 1).to_i
    page = 1 if page < 1
    per_page = 20
    total = scope.count
    total_pages = (total.to_f / per_page).ceil
    records = scope.limit(per_page).offset((page - 1) * per_page)
    [ records, total, page, total_pages.positive? ? total_pages : 1 ]
  end
end
