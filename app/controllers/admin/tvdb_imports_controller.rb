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
    show_data = client.series_details(params[:series_id])
    episodes = client.episodes_for_series(params[:series_id])

    show_name = show_data["name"] || show_data["seriesName"] || params[:query].presence || "Series #{params[:series_id]}"
    show_description = show_data["overview"] || show_data["description"]

    show = Show.find_or_create_by!(name: show_name) do |s|
      s.description = show_description
    end

    imported = 0
    episodes.each do |episode_data|
      attrs = episode_attributes_from_api(show, episode_data)
      next unless attrs[:title].present?

      episode = Episode.find_or_initialize_by(show: show, title: attrs[:title])
      episode.assign_attributes(attrs)
      imported += 1 if episode.save
    end

    redirect_to admin_episodes_path, notice: "Imported #{imported} episodes for #{show.name}."
  rescue Tvdb::Client::Error => e
    redirect_to admin_tvdb_import_path(query: params[:query]), alert: "Import failed: #{e.message}"
  end

  private

  def search_shows(query)
    Tvdb::Client.new.search_series(query)
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
