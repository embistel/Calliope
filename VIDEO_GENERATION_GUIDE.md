# Video Generation Feature

## Overview
The video generation feature allows users to create FullHD videos from their dubbing projects by combining images with audio narration.

## Features

### 1. Video Generation
- **Resolution**: FullHD (1920x1080)
- **Frame Rate**: 30 FPS
- **Duration**: 5 seconds per audio segment
- **Format**: MP4 (H.264 video, AAC audio)

### 2. User Interface
- **Generate Button**: Starts video generation (only visible when all items have audio)
- **Progress Bar**: Shows real-time generation progress (0-100%)
- **Cancel Button**: Allows users to stop generation mid-process
- **Video Player**: Built-in HTML5 player for preview
- **Download Button**: Direct download of generated video
- **Regenerate Button**: Create a new video with updated content

### 3. Process Flow

#### Step 1: Preparation
1. User creates dubbing items with images and text
2. Audio is generated for each item (using TTS)
3. "Generate Video" button becomes available

#### Step 2: Generation
1. User clicks "Generate Video"
2. Backend validates all items have audio
3. VideoGeneratorJob is queued for async processing
4. Progress updates are broadcast via Turbo Streams

#### Step 3: Processing
1. Images are resized to FullHD
2. Audio files are downloaded
3. FFmpeg creates video segments
4. Segments are concatenated into final video
5. Video is attached to project

#### Step 4: Completion
1. Video player appears with generated video
2. Download button enables file download
3. User can regenerate video if needed

## Technical Implementation

### Backend Components

#### Database Schema
```ruby
# Projects table
- video_status: string ('not_started', 'generating', 'completed', 'failed', 'cancelled')
- video_progress: integer (0-100)
- video_attachment: ActiveStorage (MP4 file)
```

#### Models
- `Project`: Has one video attachment with status tracking
- `VideoGeneratorService`: Core video generation logic
- `VideoGeneratorJob`: Async job for background processing

#### Routes
```ruby
POST /projects/:id/generate_video  # Start generation
POST /projects/:id/cancel_video     # Cancel generation
```

#### Controllers
- `ProjectsController`: Handle video generation requests
- Status updates via Turbo Streams

### Frontend Components

#### Views
- `_video_controls.html.erb`: Dynamic UI based on generation status
- Shows different states: not_started, generating, completed

#### Controllers
- `video_generator_controller.js`: Handle user interactions
- Subscribe to Turbo Streams for real-time updates

#### CSS
- Styled containers for different states
- Progress bar animations
- Responsive video player

## Dependencies

### System Requirements
- **FFmpeg**: Video processing and encoding
- **ImageMagick**: Image resizing and manipulation

### Installation
```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg imagemagick

# Docker
# Already included in Dockerfile
```

## Progress Tracking

### Progress Stages
1. **0-30%**: Image and audio file preparation
2. **30-60%**: FFmpeg video encoding
3. **60-80%**: Final video assembly
4. **80-100%**: Attaching video to project

### Real-time Updates
- Progress broadcast via Turbo::StreamsChannel
- Channel: `project_#{project_id}`
- Target: `project_video_controls`

## Error Handling

### Validation
- Checks all items have audio before generation
- Validates image and audio attachments

### Failure States
- **Failed**: Shows error message, allows retry
- **Cancelled**: Stops generation, allows restart

## Usage Example

1. Create a project with multiple dubbing items
2. Add images and text to each item
3. Generate audio for all items
4. Click "Generate Video" button
5. Watch progress bar fill up
6. Preview or download completed video
7. Optionally regenerate with changes

## Future Enhancements

Potential improvements:
- Custom video resolution options
- Adjustable duration per segment
- Video transitions/effects
- Subtitle overlay
- Background music support
- Multiple export formats