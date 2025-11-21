class Admin::TvdbImportsController < ApplicationController
  before_action :require_admin!

  def new
    @query = params[:query].to_s.strip
    @results = @query.present? ? search_shows(@query) : []
  rescue Tvdb::Client::Error => e
    flash.now[:alert] = e.message
    @results = []
  end

  def create
    client = Tvdb::Client.new
    @series_id = params[:series_id].to_s
    @query = params[:query]
    show_data = client.series_details(@series_id)

    @show_name = show_data["name"] || show_data["seriesName"] || @query.presence || "Series #{@series_id}"
    @show_description = show_data["overview"] || show_data["description"]

    respond_to do |format|
      format.html { render :create }
      format.turbo_stream { render :create, formats: :html }
    end
  rescue Tvdb::Client::Error => e
    redirect_to admin_tvdb_import_path(query: params[:query]), alert: "Import failed: #{e.message}"
  end

  def batch
    client = Tvdb::Client.new
    page = params.fetch(:page, 0).to_i
    page = 0 if page.negative?
    series_id = params[:series_id].to_s
    return render json: { error: "series_id missing" }, status: :unprocessable_entity if series_id.blank?

    show_name = params[:show_name].presence || "Series #{series_id}"
    show_description = params[:show_description]

    show = Show.find_or_create_by!(name: show_name) do |s|
      s.description = show_description
    end
    if show_description.present? && show.description.blank?
      show.update(description: show_description)
    end

    response = client.episodes_page(series_id, page:)
    result = import_batch(show, response[:episodes])

    render json: {
      page: page,
      next_page: response[:next_page],
      total_pages: response[:total_pages],
      created: result.count { _1[:status] == :created },
      updated: result.count { _1[:status] == :updated },
      unchanged: result.count { _1[:status] == :unchanged },
      skipped: result.count { _1[:status] == :skipped },
      entries: format_entries(result)
    }
  rescue Tvdb::Client::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def search_shows(query)
    Tvdb::Client.new.search_series(query)
  end

  def import_batch(show, episode_data)
    return [] unless episode_data.is_a?(Array)

    episode_data.map do |data|
      attrs = episode_attributes_from_api(show, data)
      next unless attrs[:title].present?

      episode = find_matching_episode(show, attrs)
      episode.assign_attributes(attrs)

      status =
        if episode.new_record?
          episode.save ? :created : :skipped
        elsif episode.changed?
          episode.save ? :updated : :skipped
        else
          :unchanged
        end

      { episode:, status: }
    end.compact
  end

  def find_matching_episode(show, attrs)
    scope = show.episodes
    if attrs[:season_number].present? && attrs[:episode_number].present?
      matched = scope.find_by(season_number: attrs[:season_number], episode_number: attrs[:episode_number])
      return matched if matched
    end

    scope.find_by("LOWER(title) = ?", attrs[:title].to_s.downcase) || scope.build
  end

  def format_entries(results)
    results.first(6).map do |entry|
      episode = entry[:episode]
      {
        title: episode.title,
        season_number: episode.season_number,
        episode_number: episode.episode_number,
        aired_on: episode.aired_on&.to_fs(:long),
        status: entry[:status]
      }
    end
  end

  def episode_attributes_from_api(show, data)
    return {} unless data.is_a?(Hash)

    {
      show:,
      title: data["name"] || data["episodeName"] || data.dig("translations", "eng", "name"),
      season_number: data["seasonNumber"] || data["airedSeason"],
      episode_number: data["number"] || data["episodeNumber"] || data["airedEpisodeNumber"],
      description: data["overview"] || data["description"] || data.dig("translations", "eng", "overview"),
      aired_on: parse_date(data["aired"])
    }
  end

  def parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
