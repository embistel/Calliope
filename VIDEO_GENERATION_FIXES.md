# Video Generation Fixes

## Summary of Changes

Fixed the video generation feature to properly create FullHD videos with real-time progress tracking.

### Issues Fixed

1. **FullHD Video Output**
   - Changed image resizing from ImageMagick (`convert`) to FFmpeg for better reliability
   - Added proper video scale filter: `scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2`
   - Ensures all video segments are exactly 1920x1080 pixels

2. **Image Timing Based on Dubbing Duration**
   - Each image now displays for the exact duration of its associated audio
   - Uses `-t file[:duration]` and `-shortest` flags in FFmpeg
   - Audio duration is calculated using `ffprobe` for precision

3. **Progress Bar Real-Time Updates**
   - Simplified JavaScript controller to rely on Rails Turbo's automatic handling
   - Added `turbo_stream_from` to application layout for real-time updates
   - Fixed `broadcast_progress` method to use proper `html` parameter instead of `partial`
   - Progress updates are broadcast during:
     - 0-30%: Media file preparation
     - 30-80%: Video segment encoding
     - 80-100%: Final concatenation and attachment

### Technical Details

#### Video Generator Service (`app/services/video_generator_service.rb`)

**Key Changes:**
- `resize_image`: Now uses FFmpeg with proper scale and padding filters
- `generate_segment`: Added video scale filter to ensure FullHD output
- `generate_video`: Improved error handling with proper logging
- `broadcast_progress`: Fixed to use `html` parameter for proper Turbo Stream rendering

**FFmpeg Command Used:**
```bash
ffmpeg -y -loop 1 -i image.jpg -i audio.wav \
  -c:v libx264 -tune stillimage -preset fast -crf 23 \
  -c:a aac -b:a 192k -pix_fmt yuv420p -r 30 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  -shortest -t <duration> output.mp4
```

#### JavaScript Controller (`app/javascript/controllers/video_generator_controller.js`)

**Simplifications:**
- Removed manual Turbo cable subscription (Rails handles this automatically)
- Removed `updateProgressDisplay` method (not needed with Turbo Streams)
- Streamlined controller to focus on action handling only

#### Application Layout (`app/views/layouts/application.html.erb`)

**Addition:**
```erb
<%= turbo_stream_from "project_#{@project&.id}" if @project %>
```

This enables real-time Turbo Stream updates for progress tracking.

### Video Generation Process

1. **Preparation (0-30%)**
   - Download and resize all images to FullHD
   - Download all audio files
   - Calculate audio durations
   - Update progress for each item processed

2. **Segment Generation (30-80%)**
   - Create individual video segments for each item
   - Each segment combines image + audio
   - Image displays for exact audio duration
   - Update progress after each segment

3. **Concatenation (80-100%)**
   - Combine all segments into final video
   - Attach video to project
   - Mark as completed

### Dependencies

All required tools are already installed in the Dockerfile:
- `ffmpeg`: Video/audio processing
- `imagemagick`: Alternative image processing (not used anymore)
- `libvips`: Image processing

### Testing

To test the video generation:

1. Create a project with multiple dubbing items
2. Upload images for each item
3. Generate dubbing audio for each item
4. Click "Generate Video" button
5. Observe progress bar updating in real-time
6. Download and verify FullHD output video

### Known Limitations

- Maximum video size depends on available disk space
- Video generation time depends on:
  - Number of items
  - Total audio duration
  - Server processing power
- Progress updates may have slight delays due to async job processing

### Future Improvements

- Add video quality settings (e.g., 1080p, 720p, 480p)
- Support for different aspect ratios
- Add video preview during generation
- Implement cancel functionality that stops FFmpeg processes
- Add support for video segments (not just images)