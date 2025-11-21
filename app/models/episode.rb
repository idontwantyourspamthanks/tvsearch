class Episode < ApplicationRecord
  belongs_to :show

  serialize :alternate_titles, coder: JSON

  attr_accessor :alternate_titles_text

  validates :title, presence: true
  validates :season_number, :episode_number, numericality: { allow_nil: true, greater_than: 0 }

  scope :recent_first, -> { order(aired_on: :desc, season_number: :desc, episode_number: :desc) }

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
end
