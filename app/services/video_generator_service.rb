require 'fileutils'
require 'open3'
require 'json'

class VideoGeneratorService
  VIDEO_WIDTH = 1920
  VIDEO_HEIGHT = 1080
  FPS = 30

  def initialize(project)
    @project = project
    @total_duration = 0
  end

  def generate!
    return unless @project.dubbing_items.any?
    return unless @project.dubbing_items.all? { |item| item.audio.attached? }

    update_status('generating', 0)

    temp_dir = Dir.mktmpdir('video_generation')
    begin
      # Prepare all images and audio files
      prepared_files = prepare_media_files(temp_dir)
      
      # Generate video using FFmpeg
      output_path = File.join(temp_dir, 'output.mp4')
      generate_video(prepared_files, output_path)
      
      # Attach video to project
      attach_video(output_path)
      
      update_status('completed', 100)
    rescue => e
      Rails.logger.error("Video generation failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      update_status('failed', @project.video_progress)
      raise e
    ensure
      FileUtils.rm_rf(temp_dir)
    end

    true
  end

  def cancel!
    # For now, just update status
    @project.update(video_status: 'cancelled')
  end

  private

  def prepare_media_files(temp_dir)
    files = []
    
    @project.dubbing_items.order(:position).each_with_index do |item, index|
      next unless item.image.attached? && item.audio.attached?
      
      # Download and prepare image
      image_path = File.join(temp_dir, "image_#{index}.jpg")
      File.binwrite(image_path, item.image.download)
      
      # Resize image to FullHD
      resized_image_path = File.join(temp_dir, "image_#{index}_resized.jpg")
      resize_image(image_path, resized_image_path)
      
      # Download audio
      audio_path = File.join(temp_dir, "audio_#{index}.wav")
      File.binwrite(audio_path, item.audio.download)
      
      # Get audio duration
      duration = get_audio_duration(audio_path)
      @total_duration += duration
      
      files << {
        image: resized_image_path,
        audio: audio_path,
        index: index,
        duration: duration
      }
      
      # Update progress (0-30% for preparation)
      progress = ((index + 1).to_f / @project.dubbing_items.count * 30).to_i
      update_progress(progress)
    end
    
    files
  end

  def get_audio_duration(audio_path)
    cmd = "ffprobe -v error -show_entries format=duration -of json #{audio_path.shellescape}"
    output = `#{cmd}`
    json = JSON.parse(output)
    json['format']['duration'].to_f.round(2)
  end

  def resize_image(input_path, output_path)
    # Use FFmpeg to resize image to FullHD - more reliable than ImageMagick
    vf_filter = "scale=#{VIDEO_WIDTH}:#{VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=#{VIDEO_WIDTH}:#{VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2"
    
    cmd = "ffmpeg -y -i #{input_path.shellescape} -vf #{vf_filter.shellescape} " \
          "-frames:v 1 -q:v 2 #{output_path.shellescape}"
    
    system(cmd)
  end

  def generate_video(files, output_path)
    return if files.empty?

    Rails.logger.info "Total video duration: #{@total_duration} seconds"

    # Create a simpler FFmpeg command using concat demuxer
    concat_list_path = File.join(File.dirname(output_path), 'concat_list.txt')
    
    # Generate individual video segments first
    segments = []
    files.each_with_index do |file, index|
      segment_path = File.join(File.dirname(output_path), "segment_#{index}.mp4")
      generate_segment(file, segment_path, index)
      segments << segment_path
      
      # Update progress (30-80% for encoding)
      progress = 30 + ((index + 1).to_f / files.count * 50).to_i
      update_progress(progress)
    end
    
    # Create concat list
    File.write(concat_list_path, segments.map { |s| "file '#{s}'" }.join("\n"))
    
    # Concatenate all segments
    concat_cmd = [
      'ffmpeg',
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', concat_list_path,
      '-c', 'copy',
      output_path.shellescape
    ].join(' ')
    
    Rails.logger.info "Concatenating with: #{concat_cmd}"
    result = system(concat_cmd)
    
    unless result
      Rails.logger.error "Video concatenation failed"
      raise "Video concatenation failed"
    end
    
    # Clean up segments
    segments.each { |s| File.delete(s) if File.exist?(s) }
    File.delete(concat_list_path) if File.exist?(concat_list_path)
  end

  def generate_segment(file, output_path, index)
    # Create a simple video segment with image and audio - ensuring FullHD output
    vf_filter = "scale=#{VIDEO_WIDTH}:#{VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=#{VIDEO_WIDTH}:#{VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2"
    
    cmd = "ffmpeg -y -loop 1 -i #{file[:image].shellescape} -i #{file[:audio].shellescape} " \
          "-c:v libx264 -tune stillimage -preset fast -crf 23 " \
          "-c:a aac -b:a 192k -pix_fmt yuv420p -r #{FPS} " \
          "-vf #{vf_filter.shellescape} " \
          "-t #{file[:duration]} #{output_path.shellescape}"
    
    Rails.logger.info "Generating segment #{index}: #{cmd}"
    
    # Use Open3 to capture stderr for better error reporting
    stdout, stderr, status = Open3.capture3(cmd)
    
    unless status.success?
      Rails.logger.error "Segment #{index} generation failed"
      Rails.logger.error "FFmpeg stderr: #{stderr}"
      raise "Segment #{index} generation failed: #{stderr}"
    end
  end

  def attach_video(output_path)
    File.open(output_path, 'rb') do |file|
      @project.video.attach(
        io: file,
        filename: "video_#{@project.id}.mp4",
        content_type: 'video/mp4'
      )
    end
  end

  def update_status(status, progress)
    @project.update(
      video_status: status,
      video_progress: progress
    )
    
    # Broadcast update via Turbo Streams
    broadcast_progress
  end

  def update_progress(progress)
    @project.update(video_progress: progress)
    
    # Broadcast update via Turbo Streams
    broadcast_progress
  end

  def broadcast_progress
    # Use Turbo::StreamsChannel with proper format
    Turbo::StreamsChannel.broadcast_update_to(
      "project_#{@project.id}",
      target: "project_video_controls",
      html: ApplicationController.render(
        partial: "projects/video_controls",
        locals: { project: @project }
      )
    )
  end
end