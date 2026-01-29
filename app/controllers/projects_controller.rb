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

  private

  def project_params
    params.require(:project).permit(:title)
  end
end
