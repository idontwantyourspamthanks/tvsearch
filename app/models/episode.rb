class Episode < ApplicationRecord
  belongs_to :show

  validates :title, presence: true
  validates :season_number, :episode_number, numericality: { allow_nil: true, greater_than: 0 }

  scope :recent_first, -> { order(aired_on: :desc, season_number: :desc, episode_number: :desc) }

  def self.search(query)
    scope = left_joins(:show).includes(:show)
    return scope if query.blank?

    sanitized_query = "%#{query.downcase.strip}%"
    scope.where(
      "LOWER(episodes.title) LIKE :q OR LOWER(episodes.description) LIKE :q OR LOWER(shows.name) LIKE :q",
      q: sanitized_query
    )
  end
end
