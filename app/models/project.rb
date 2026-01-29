class Project < ApplicationRecord
  has_many :dubbing_items, -> { order(position: :asc) }, dependent: :destroy
end
