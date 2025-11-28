require "net/http"
require "fileutils"
require "pathname"
require "securerandom"

class EpisodeImageDownloader
  CACHE_DIR = Rails.root.join("public", "episode_images")

  def self.download(episode)
    new(episode).download
  end

  def self.cached_image_present?(episode)
    new(episode).send(:cached_image_present?)
  end

  def initialize(episode)
    @episode = episode
  end

  def download
    return false unless @episode.image_url.present?

    if cached_image_present?
      Rails.logger.info "Image already cached for episode #{@episode.id} (#{cached_image_path})"
      return true
    elsif @episode.image_path.present?
      Rails.logger.warn "Cached image missing or empty for episode #{@episode.id} (expected at #{cached_image_path}) - attempting re-download"
    end

    Rails.logger.info "Attempting to download image for episode #{@episode.id} (#{@episode.title})"
    Rails.logger.info "  Image URL: #{@episode.image_url}"
    Rails.logger.info "  Cache dir: #{CACHE_DIR}"

    # Ensure cache directory exists
    FileUtils.mkdir_p(CACHE_DIR)
    Rails.logger.info "  Cache dir exists: #{Dir.exist?(CACHE_DIR)}"
    Rails.logger.info "  Cache dir writable: #{File.writable?(CACHE_DIR)}"

    # Download the image
    uri = URI(@episode.image_url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "  HTTP request failed: #{response.code} #{response.message}"
      return false
    end

    Rails.logger.info "  Download successful, size: #{response.body.bytesize} bytes"

    # Determine file extension from URL or content type
    extension = determine_extension(uri, response)
    filename_root = @episode.tvdb_id.presence || @episode.id || SecureRandom.hex(6)
    filename = "#{filename_root}#{extension}"
    file_path = CACHE_DIR.join(filename)

    Rails.logger.info "  Saving to: #{file_path}"

    # Write the image to disk
    File.binwrite(file_path, response.body)

    # Update episode with cached path
    @episode.update!(
      image_path: "episode_images/#{filename}",
      image_updated_at: Time.current
    )

    Rails.logger.info "  SUCCESS: Image cached and database updated"
    true
  rescue StandardError => e
    Rails.logger.error "Failed to download image for episode #{@episode.id}: #{e.class} - #{e.message}"
    Rails.logger.error "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
    false
  end

  private

  def cached_image_present?
    path = cached_image_path
    return false unless path

    File.file?(path) && File.size(path).positive?
  end

  def cached_image_path
    return unless @episode.image_path.present?

    relative_path = @episode.image_path.to_s.delete_prefix("/")
    full_path = Rails.root.join("public", relative_path)
    Pathname.new(full_path)
  end

  def determine_extension(uri, response)
    # Try to get extension from URL
    if uri.path =~ /\.(jpg|jpeg|png|gif|webp)$/i
      return ".#{$1.downcase}"
    end

    # Fall back to content type
    content_type = response["content-type"]
    case content_type
    when /jpeg|jpg/i then ".jpg"
    when /png/i then ".png"
    when /gif/i then ".gif"
    when /webp/i then ".webp"
    else ".jpg" # Default
    end
  end
end
