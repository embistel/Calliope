class DubbingItem < ApplicationRecord
  belongs_to :project
  has_one_attached :image
  
  acts_as_list scope: :project
  
  # before_create :set_position # acts_as_list handles this

  private

  # def set_position
  #   self.position ||= (project.dubbing_items.maximum(:position) || 0) + 1
  # end
end
