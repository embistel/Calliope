class ProjectsController < ApplicationController
  def index
    if @sidebar_projects.any?
      redirect_to project_path(@sidebar_projects.first)
    else
      redirect_to project_path(Project.create!(title: "Untitled Project"))
    end
  end

  def show
    @project = Project.find(params[:id])
  end

  def create
    @project = Project.create!(title: "New Project #{Project.count + 1}")
    redirect_to project_path(@project)
  end

  def update
    @project = Project.find(params[:id])
    if @project.update(project_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project }
      end
    end
  end

  def destroy
    @project = Project.find(params[:id])
    @project.destroy
    redirect_to projects_path, notice: "Project was successfully deleted."
  end

  def generate_video
    @project = Project.find(params[:id])
    
    # Check if all items have audio
    unless @project.dubbing_items.all? { |item| item.audio.attached? }
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("project_video_controls", partial: "projects/video_controls", locals: { project: @project, error: "모든 항목에 오디오가 생성되어야 합니다." }) }
        format.html { redirect_to @project, alert: "All items must have audio generated" }
      end
      return
    end
    
    # Generate video asynchronously
    VideoGeneratorJob.perform_later(@project.id)
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("project_video_controls", partial: "projects/video_controls", locals: { project: @project }) }
      format.html { redirect_to @project, notice: "Video generation started" }
    end
  end

  def cancel_video
    @project = Project.find(params[:id])
    @project.update(video_status: 'cancelled')
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("project_video_controls", partial: "projects/video_controls", locals: { project: @project }) }
      format.html { redirect_to @project, notice: "Video generation cancelled" }
    end
  end

  private

  def project_params
    params.require(:project).permit(:title, :video_status, :video_progress)
  end
end
