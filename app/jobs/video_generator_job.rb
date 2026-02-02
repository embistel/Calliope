class VideoGeneratorJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find(project_id)
    
    # Check if still generating (not cancelled)
    return if project.video_status == 'cancelled'
    
    service = VideoGeneratorService.new(project)
    service.generate!
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Project #{project_id} not found for video generation"
  rescue => e
    Rails.logger.error "Video generation job failed: #{e.message}"
    project&.update(video_status: 'failed')
  end
end