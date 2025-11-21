class Admin::EpisodesController < ApplicationController
  before_action :require_admin!
  before_action :set_episode, only: %i[edit update destroy]

  def index
    @episodes = Episode.includes(:show).recent_first
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
end
