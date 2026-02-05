class Project < ApplicationRecord
  has_many :dubbing_items, -> { order(position: :asc) }, dependent: :destroy
  has_one_attached :video
  
  before_create :set_default_video_status
  after_initialize :set_default_video_status
  
  def set_default_video_status
    self.video_status ||= 'not_started'
    self.video_progress ||= 0
  end
end
