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
    @series_id = params[:series_id].to_s
    @query = params[:query]

    if @series_id.blank?
      redirect_to admin_tvdb_import_path(query: @query), alert: "Series ID missing."
      return
    end

    render :create
  end

  def details
    series_id = params[:series_id].to_s
    return render json: { error: "series_id missing" }, status: :unprocessable_entity if series_id.blank?

    client = Tvdb::Client.new
    data = client.series_details(series_id)
    seasons = client.series_seasons(series_id)

    render json: {
      series_id:,
      show_name: data["name"] || data["seriesName"] || "Series #{series_id}",
      show_description: data["overview"] || data["description"],
      tvdb_id: data["id"] || data["tvdb_id"],
      seasons:
    }
  rescue Tvdb::Client::Error => e
    render json: { error: e.message, error_class: e.class.name, detail: e.backtrace&.first }, status: :bad_gateway
  end

  def batch
    client = Tvdb::Client.new
    series_id = params[:series_id].to_s
    return render json: { error: "series_id missing" }, status: :unprocessable_entity if series_id.blank?

    page = params.fetch(:page, 0).to_i
    page = 0 if page.negative?

    show_name = params[:show_name].presence || "Series #{series_id}"
    show_description = params[:show_description]
    selected_seasons = params[:selected_seasons] || []

    show = find_or_prepare_show(series_id, show_name, show_description)

    response = client.episodes_page(series_id, page:)

    # Filter episodes by selected seasons if specified
    episodes = response[:episodes]
    if selected_seasons.any?
      season_numbers = selected_seasons.map(&:to_i)
      episodes = episodes.select { |ep| season_numbers.include?(ep["seasonNumber"] || ep["airedSeason"]) }
    end

    result = import_batch(show, episodes)

    render json: {
      page:,
      fetched: episodes.size,
      next_page: response[:next_page],
      total_pages: response[:total_pages],
      created: result.count { _1[:status] == :created },
      updated: result.count { _1[:status] == :updated },
      unchanged: result.count { _1[:status] == :unchanged },
      skipped: result.count { _1[:status] == :skipped },
      entries: format_entries(result)
    }
  rescue Tvdb::Client::Error => e
    render json: { error: e.message, error_class: e.class.name, detail: e.backtrace&.first, page: }, status: :bad_gateway
  end

  private

  def search_shows(query)
    Tvdb::Client.new.search_series(query)
  end

  def import_batch(show, episode_data)
    return [] unless episode_data.is_a?(Array)

    episode_data.map do |data|
      attrs = episode_attributes_from_api(show, data)

      unless attrs[:title].present?
        next {
          episode: nil,
          status: :skipped,
          reason: "Missing title",
          data: { tvdb_id: attrs[:tvdb_id], season: attrs[:season_number], episode: attrs[:episode_number] }
        }
      end

      episode = find_matching_episode(show, attrs)
      apply_episode_attributes(episode, attrs)

      if episode.new_record?
        if episode.save
          status = :created
          reason = nil
        else
          status = :skipped
          reason = episode.errors.full_messages.join(", ")
        end
      elsif episode.changed?
        if episode.save
          status = :updated
          reason = "Updated: #{episode.previous_changes.keys.join(', ')}"
        else
          status = :skipped
          reason = episode.errors.full_messages.join(", ")
        end
      else
        status = :unchanged
        reason = "Already up to date"
      end

      # Always try to download image if we have a URL but no cached file
      if episode.persisted? && episode.image_url.present? && episode.image_path.blank?
        download_success = EpisodeImageDownloader.download(episode)
        Rails.logger.info "Image download for episode #{episode.id}: #{download_success ? 'SUCCESS' : 'FAILED'}"
      end

      { episode:, status:, reason: }
    end.compact
  end

  def format_entries(results)
    results.first(8).map do |entry|
      episode = entry[:episode]

      if episode
        {
          title: episode.title,
          season_number: episode.season_number,
          episode_number: episode.episode_number,
          aired_on: episode.aired_on&.to_fs(:long),
          status: entry[:status],
          reason: entry[:reason]
        }
      else
        # Episode was skipped before creation (e.g., missing title)
        {
          title: "Unknown Episode",
          season_number: entry.dig(:data, :season),
          episode_number: entry.dig(:data, :episode),
          aired_on: nil,
          status: entry[:status],
          reason: entry[:reason]
        }
      end
    end
  end

  def find_matching_episode(show, attrs)
    scope = show.episodes
    if attrs[:tvdb_id].present?
      matched = scope.find_by(tvdb_id: attrs[:tvdb_id])
      return matched if matched
    end

    if attrs[:season_number].present? && attrs[:episode_number].present?
      matched = scope.find_by(season_number: attrs[:season_number], episode_number: attrs[:episode_number])
      return matched if matched
    end

    scope.find_by("LOWER(title) = ?", attrs[:title].to_s.downcase) || scope.build
  end

  def find_or_prepare_show(series_id, show_name, show_description)
    tvdb_id = series_id.to_i
    tvdb_id = nil if tvdb_id.zero? && series_id.blank?

    show = tvdb_id ? Show.find_by(tvdb_id:) : nil
    show ||= Show.find_or_initialize_by(name: show_name)

    show.tvdb_id = tvdb_id if show.tvdb_id.blank? && tvdb_id.present?
    show.description = show_description if show.description.blank? && show_description.present?
    show.save! if show.new_record? || show.changed?
    show
  end

  def episode_attributes_from_api(show, data)
    return {} unless data.is_a?(Hash)

    {
      show:,
      tvdb_id: tvdb_episode_id(data),
      title: data["name"] || data["episodeName"] || data.dig("translations", "eng", "name"),
      season_number: data["seasonNumber"] || data["airedSeason"],
      episode_number: data["number"] || data["episodeNumber"] || data["airedEpisodeNumber"],
      description: data["overview"] || data["description"] || data.dig("translations", "eng", "overview"),
      aired_on: parse_date(data["aired"]),
      image_url: extract_image_url(data)
    }
  end

  def tvdb_episode_id(data)
    value = data["id"] || data["tvdb_id"]
    return unless value.present?

    value.to_i
  end

  def parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def extract_image_url(data)
    image = data["image"]
    return nil if image.blank?

    # If it's already a full URL, return it
    return image if image.start_with?("http://", "https://")

    # Otherwise prepend the TVDB artwork base URL
    "https://artworks.thetvdb.com#{image}"
  end

  def apply_episode_attributes(episode, attrs)
    return episode.assign_attributes(attrs) if episode.new_record?

    safe_attrs = attrs.each_with_object({}) do |(key, value), memo|
      next if key == :show
      next if value.blank?

      current_value = episode.public_send(key)
      memo[key] = value if current_value.blank?
    end

    episode.assign_attributes(safe_attrs)
  end
end
