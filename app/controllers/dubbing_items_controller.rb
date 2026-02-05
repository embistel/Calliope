class DubbingItemsController < ApplicationController
  before_action :set_project
  before_action :set_dubbing_item, only: [:show, :edit, :update, :destroy, :generate_dubbing]

  def index
    @dubbing_items = @project.dubbing_items.order(:position)
  end

  def show
  end

  def new
    @dubbing_item = @project.dubbing_items.build
  end

  def create
    @dubbing_item = @project.dubbing_items.build(dubbing_item_params)
    if @dubbing_item.save
      redirect_to [@project, @dubbing_item], notice: 'Dubbing item was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @dubbing_item.update(dubbing_item_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@dubbing_item, partial: "dubbing_items/dubbing_item", locals: { dubbing_item: @dubbing_item }) }
        format.html { redirect_to [@project, @dubbing_item], notice: 'Dubbing item was successfully updated.' }
      end
    else
      render :edit
    end
  end

  def destroy
    @dubbing_item.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@dubbing_item) }
      format.html { redirect_to @project, notice: 'Dubbing item was successfully deleted.' }
    end
  end

  def move_up
    @dubbing_item.move_higher
    redirect_to @project
  end

  def move_down  
    @dubbing_item.move_lower
    redirect_to @project
  end

  def generate_dubbing
    text = @dubbing_item.content
    Rails.logger.info "Generating dubbing for item #{@dubbing_item.id} with text: #{text}"
    
    return unless text.present?

    # Prepare paths
    wav_path = Rails.root.join('tmp', 'audio', "dubbing_#{@dubbing_item.id}.wav")
    FileUtils.mkdir_p(File.dirname(wav_path))
    
    # Create request for TTS daemon
    require 'json'
    require 'securerandom'
    
    request_id = SecureRandom.uuid
    request_dir = "/tmp/tts_requests"
    response_dir = "/tmp/tts_responses"
    FileUtils.mkdir_p(request_dir)
    FileUtils.mkdir_p(response_dir)
    
    request_file = "#{request_dir}/#{request_id}.json"
    response_file = "#{response_dir}/#{request_id}.json"
    
    request_data = {
      text: text,
      language: "Korean",
      speaker: "Sohee", 
      instruct: @dubbing_item.instruct.presence || "밝고 명랑한 목소리로 말해주세요",
      max_new_tokens: 2048,
      output_path: wav_path.to_s
    }
    
    # Ensure TTS daemon is running
    unless system("pgrep -f tts_daemon.py > /dev/null")
      Rails.logger.info "Starting TTS daemon..."
      
      # Start daemon in background
      python_cmd = Rails.root.join('Qwen3-TTS', 'venv', 'bin', 'python3').to_s
      python_cmd = "python3" unless File.exist?(python_cmd)
      
      system(
        "#{python_cmd} #{Rails.root}/app/services/tts_daemon.py > #{Rails.root}/tts_daemon.log 2>&1 &"
      )
      
      # Wait for daemon to be ready
      Rails.logger.info "Waiting for TTS daemon to start..."
      60.times do
        break if system("pgrep -f tts_daemon.py > /dev/null")
        sleep 1
      end
      
      # Additional wait for model loading
      Rails.logger.info "Waiting for model to load..."
      sleep 25
    end
    
    begin
      # Write request file
      File.write(request_file, request_data.to_json)
      Rails.logger.info "TTS request sent: #{request_id}"
      
      # Wait for response (with timeout)
      response = nil
      300.times do # 5 minute timeout
        if File.exist?(response_file)
          response = JSON.parse(File.read(response_file))
          File.delete(response_file)
          break
        end
        sleep 1
      end
      
      if response.nil?
        raise "TTS request timed out after 5 minutes"
      elsif response['status'] == 'error'
        raise "TTS generation failed: #{response['error']}"
      elsif response['status'] == 'success' && File.exist?(wav_path)
        Rails.logger.info "Audio generated successfully: %.2fs audio in %.2fs" % [response['duration'], response['generation_time']]
        
        @dubbing_item.audio.attach(
          io: File.open(wav_path),
          filename: "dubbing_#{@dubbing_item.id}.wav",
          content_type: "audio/wav"
        )
        
        File.delete(wav_path) if File.exist?(wav_path)
        Rails.logger.info "Audio attached successfully"
      else
        raise "Audio generation succeeded but file not found"
      end
      
    rescue => e
      Rails.logger.error "Error in TTS generation: #{e.message}"
      # Clean up request file if it still exists
      File.delete(request_file) if File.exist?(request_file)
      # Don't raise error to user, just log it
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@dubbing_item, partial: "dubbing_items/dubbing_item", locals: { dubbing_item: @dubbing_item }) }
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
    params.require(:dubbing_item).permit(:content, :instruct)
  end
end