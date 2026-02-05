class DubbingItemsController < ApplicationController
  before_action :set_project
  before_action :set_dubbing_item, only: [:update, :destroy, :upload_image, :generate_dubbing]

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

  def generate_dubbing
    text = @dubbing_item.content
    Rails.logger.info "Generating dubbing for item #{@dubbing_item.id} with text: #{text}"
    
    return unless text.present?

    # Create log directory if it doesn't exist
    log_dir = Rails.root.join('log', 'dubbing')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    log_file = log_dir.join("dubbing_#{@dubbing_item.id}_#{timestamp}.log")
    
    require 'open3'
    
    # Output file path
    wav_path = Rails.root.join('tmp', "dubbing_#{@dubbing_item.id}_#{timestamp}.wav")
    
    require 'json'
    safe_text = text.to_json
    instruct = @dubbing_item.instruct.presence || "밝고 명랑한 목소리로 말해주세요"
    safe_instruct = instruct.to_json

    # Use local Qwen3-TTS for Korean text-to-speech
    python_script = <<~PYTHON
      import sys
      import logging
      import os
      import time
      import json
      
      # Add Qwen3-TTS to path
      qwen_path = "#{Rails.root.join('Qwen3-TTS')}"
      sys.path.insert(0, qwen_path)
      
      # Setup logging to file and console
      logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
          logging.FileHandler('#{log_file}'),
          logging.StreamHandler()
        ]
      )
      
      import torch
      import soundfile as sf
      from qwen_tts import Qwen3TTSModel
      
      # Text content
      text = #{safe_text}
      instruct = #{safe_instruct}
      
      logging.info("="*60)
      logging.info("Starting Qwen3-TTS generation")
      logging.info(f"Dubbing item ID: #{@dubbing_item.id}")
      logging.info(f"Text to synthesize: {text}")
      logging.info(f"Instruct: {instruct}")
      logging.info(f"Text length: {len(text)} characters")
      logging.info("="*60)
      
      # Check device availability
      device = "cuda:0" if torch.cuda.is_available() else "cpu"
      logging.info(f"Using device: {device}")
      
      # Use the tested model path
      MODEL_PATH = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
      
      logging.info("Loading Qwen3-TTS model...")
      logging.info(f"Model path: {MODEL_PATH}")
      
      try:
        t0 = time.time()
        tts = Qwen3TTSModel.from_pretrained(
          MODEL_PATH,
          device_map=device,
          dtype=torch.bfloat16 if device.startswith("cuda") else torch.float32,
          trust_remote_code=True,
        )
        t1 = time.time()
        logging.info(f"Model loaded successfully in {t1 - t0:.2f}s")
      except Exception as e:
        logging.error(f"Failed to load model: {str(e)}")
        raise
      
      # Generate Korean dubbing
      logging.info("Generating Korean dubbing...")
      try:
        t0 = time.time()
        wavs, sr = tts.generate_custom_voice(
          text=text,
          language="Korean",
          speaker="Sohee",
          instruct=instruct,
          max_new_tokens=2048,
        )
        t1 = time.time()
        logging.info(f"Audio generated in {t1 - t0:.2f}s: {len(wavs)} samples, sample rate: {sr}")
      except Exception as e:
        logging.error(f"Failed to generate audio: {str(e)}")
        raise
      
      # Save to WAV file
      sf.write("#{wav_path}", wavs[0], sr)
      logging.info(f"Audio saved successfully to: #{wav_path}")
      
      file_size = os.path.getsize("#{wav_path}")
      logging.info(f"File size: {file_size} bytes")
      
      logging.info("="*60)
      logging.info("SUCCESS: Dubbing generation completed")
      logging.info("="*60)
      
      print(f"SUCCESS: Audio generated and saved to #{wav_path}")
    PYTHON

    script_path = Rails.root.join('tmp', "generate_dubbing_#{@dubbing_item.id}.py")
    File.write(script_path, python_script)

    # Use the venv python if available, otherwise fallback to system python3
    python_cmd = Rails.root.join('Qwen3-TTS', 'venv', 'bin', 'python3').to_s
    python_cmd = "python3" unless File.exist?(python_cmd)

    # Execute Python script and capture output
    output, status = Open3.capture2e(
      "#{python_cmd} #{script_path}",
      chdir: Rails.root
    )
    
    # Write output to log file
    File.write(log_file, "\n\n=== RAW OUTPUT ===\n#{output}\n", mode: 'a') if log_file
    Rails.logger.info "Dubbing generation output: #{output}"

    if status.success? && File.exist?(wav_path)
      @dubbing_item.audio.attach(
        io: File.open(wav_path),
        filename: "dubbing_#{@dubbing_item.id}.wav",
        content_type: 'audio/wav'
      )
      
      # Write final result to log
      File.write(log_file, "\n=== FINAL RESULT ===\nAudio File Attached: dubbing_#{@dubbing_item.id}.wav\nLocal Path: #{wav_path}\n", mode: 'a') if log_file
      
      # Clean up WAV file
      File.delete(wav_path) if File.exist?(wav_path)
    else
      # Write error to log
      File.write(log_file, "\n=== ERROR ===\nExit status: #{status}\n", mode: 'a') if log_file
    end

    # Clean up Python script
    File.delete(script_path) if File.exist?(script_path)

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
