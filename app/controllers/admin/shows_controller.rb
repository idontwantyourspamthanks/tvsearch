class Admin::ShowsController < ApplicationController
  before_action :require_admin!
  before_action :set_show, only: %i[edit update destroy]

  def index
    @shows = Show.order(:name)
  end

  def new
    @show = Show.new
  end

  def create
    @show = Show.new(show_params)
    respond_to do |format|
      if @show.save
        format.html { redirect_to admin_shows_path, notice: "Show created." }
        format.turbo_stream do
          @episode = Episode.new(show: @show)
          render :create
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("modal", partial: "modal", locals: { show: @show }),
                 status: :unprocessable_entity
        end
      end
    end
  end

  def edit; end

  def update
    if @show.update(show_params)
      redirect_to admin_shows_path, notice: "Show updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @show.destroy
    redirect_to admin_shows_path, notice: "Show removed."
  end

  private

  def set_show
    @show = Show.find(params[:id])
  end

  def show_params
    params.require(:show).permit(:name, :description)
  end
end
