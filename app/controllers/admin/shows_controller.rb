class Admin::ShowsController < ApplicationController
  before_action :require_admin!
  before_action :set_show, only: %i[edit update destroy]

  def index
    @query = params[:q].to_s.strip
    scope = Show.order(:name)
    scope = scope.where("LOWER(name) LIKE ?", "%#{@query.downcase}%") if @query.present?
    @shows, @shows_total, @current_page, @total_pages = paginate(scope)
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
    params.require(:show).permit(:name, :description, :emoji)
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
