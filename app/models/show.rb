class Show < ApplicationRecord
  has_many :episodes, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
