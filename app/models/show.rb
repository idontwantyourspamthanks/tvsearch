class Show < ApplicationRecord
  has_many :episodes, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :tvdb_id, uniqueness: true, allow_nil: true
end
