class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_sidebar_projects

  private

  def set_sidebar_projects
    if Project.count == 0
      Project.create!(title: "Untitled Project")
    end
    @sidebar_projects = Project.order(created_at: :asc)
  end
end
