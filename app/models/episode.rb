class Episode < ApplicationRecord
  belongs_to :show

  serialize :alternate_titles, coder: JSON

  attr_accessor :alternate_titles_text

  validates :title, presence: true
  validates :season_number, :episode_number, numericality: { allow_nil: true, greater_than_or_equal_to: 0 }
  validates :tvdb_id, uniqueness: true, allow_nil: true

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
    sanitized_query = "%#{query.to_s.downcase.strip}%"
    relevance_sql = sanitize_sql_array([
      <<~SQL.squish, q: sanitized_query
        CASE
          WHEN LOWER(episodes.title) LIKE :q THEN 3
          WHEN LOWER(episodes.alternate_titles) LIKE :q THEN 2
          WHEN LOWER(episodes.description) LIKE :q THEN 1
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

    sanitized_query = "%#{query.downcase.strip}%"
    scope.where(
      "LOWER(episodes.title) LIKE :q OR LOWER(episodes.description) LIKE :q OR LOWER(shows.name) LIKE :q OR LOWER(episodes.alternate_titles) LIKE :q",
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
end
