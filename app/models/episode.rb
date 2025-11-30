class Episode < ApplicationRecord
  belongs_to :show

  serialize :alternate_titles, coder: JSON

  attr_accessor :alternate_titles_text

  validates :title, presence: true
  validates :season_number, :episode_number, numericality: { allow_nil: true, greater_than_or_equal_to: 0 }
  validates :tvdb_id, uniqueness: true, allow_nil: true

  ACCENT_REPLACEMENTS = {
    "àáâäãåāąă" => "a",
    "çćč" => "c",
    "ďđ" => "d",
    "èéêëēęěė" => "e",
    "îïíīįì" => "i",
    "ł" => "l",
    "ñńň" => "n",
    "ôöòóøōõ" => "o",
    "ŕř" => "r",
    "šśşș" => "s",
    "ťţț" => "t",
    "ûüùúūű" => "u",
    "ýÿ" => "y",
    "žźż" => "z"
  }.freeze

  scope :recent_first, -> { order(aired_on: :desc, season_number: :desc, episode_number: :desc) }
  scope :by_show_episode, lambda {
    left_joins(:show).order(
      Arel.sql("LOWER(shows.name) ASC"),
      :season_number,
      :episode_number,
      :aired_on
    )
  }

  scope :order_by_relevance, lambda { |query|
    sanitized_query = "%#{I18n.transliterate(query.to_s).downcase.strip}%"
    relevance_sql = sanitize_sql_array([
      <<~SQL.squish, q: sanitized_query
        CASE
          WHEN #{normalized_field_sql("episodes.title")} LIKE :q THEN 3
          WHEN #{normalized_field_sql("episodes.alternate_titles")} LIKE :q THEN 2
          WHEN #{normalized_field_sql("episodes.description")} LIKE :q THEN 1
          ELSE 0
        END
      SQL
    ])

    left_joins(:show).order(
      Arel.sql("#{relevance_sql} DESC"),
      Arel.sql("LOWER(shows.name) ASC"),
      :season_number,
      :episode_number,
      :aired_on
    )
  }

  def self.search(query)
    scope = left_joins(:show).includes(:show)
    return scope if query.blank?

    sanitized_query = "%#{I18n.transliterate(query.to_s).downcase.strip}%"
    scope.where(
      <<~SQL.squish,
        #{normalized_field_sql("episodes.title")} LIKE :q OR
        #{normalized_field_sql("episodes.description")} LIKE :q OR
        #{normalized_field_sql("shows.name")} LIKE :q OR
        #{normalized_field_sql("episodes.alternate_titles")} LIKE :q
      SQL
      q: sanitized_query
    )
  end

  def alternate_titles_text
    @alternate_titles_text.presence || alternate_titles&.join(", ")
  end

  def alternate_titles_text=(value)
    @alternate_titles_text = value
    self.alternate_titles = value.to_s.split(",").map { |val| val.strip.presence }.compact
  end

  def display_image_url
    # Prefer local cached image, fall back to remote URL
    return "/#{image_path}" if image_path.present?

    image_url
  end

  def self.normalized_field_sql(column)
    base = "LOWER(#{column})"
    ACCENT_REPLACEMENTS.reduce(base) do |sql, (chars, replacement)|
      chars.chars.reduce(sql) { |inner_sql, char| "REPLACE(#{inner_sql}, '#{char}', '#{replacement}')" }
    end
  end
end
