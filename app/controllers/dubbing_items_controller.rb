class DubbingItemsController < ApplicationController
  before_action :set_project
  before_action :set_dubbing_item, only: [:update, :destroy, :upload_image]

  def create
    if params[:insert_after].present?
      @previous_item = @project.dubbing_items.find(params[:insert_after])
      @dubbing_item = @project.dubbing_items.create!(content: "")
      @dubbing_item.insert_at(@previous_item.position + 1)
      @insert_mode = true
    else
      @dubbing_item = @project.dubbing_items.create!(content: "")
      @insert_mode = false
    end
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project }
    end
  end

  def update
    @dubbing_item.update(dubbing_item_params)
    
    respond_to do |format|
      # Don't render anything for turbo_stream on success to prevent focus loss
      format.turbo_stream { head :ok }
      format.html { redirect_to @project }
    end
  end

  def destroy
    @dubbing_item.destroy
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@dubbing_item) }
      format.html { redirect_to @project }
    end
  end

  def upload_image
    @dubbing_item.update(content: params[:content]) if params[:content].present?
    
    if params[:image].present?
      @dubbing_item.image.attach(params[:image])
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@dubbing_item, partial: "dubbing_items/dubbing_item", locals: { dubbing_item: @dubbing_item, autofocus: true }) }
      format.html { redirect_to @project }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_dubbing_item
    @dubbing_item = @project.dubbing_items.find(params[:id])
  end

  def dubbing_item_params
    params.require(:dubbing_item).permit(:content)
  end
end
