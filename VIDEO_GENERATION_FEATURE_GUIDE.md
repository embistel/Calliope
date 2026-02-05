# Video Generation Feature Guide

## Overview
The video generation feature allows users to combine registered photos and dubbing audio files to create MP4 videos with real-time progress tracking.

## Features

### 1. Video Generation Button
- **Location**: `app/views/projects/_video_controls.html.erb`
- **Functionality**: 
  - Displays "Generate Video" button when video status is 'not_started', 'failed', or 'cancelled'
  - Button is disabled/hidden until all dubbing items have audio files attached
  - Triggers asynchronous video generation via `VideoGeneratorJob`

### 2. Progress Bar
- **Location**: `app/views/projects/_video_controls.html.erb`
- **Styles**: `app/assets/stylesheets/application.css` (`.video-progress-bar`, `.video-progress-fill`)
- **Functionality**:
  - Shows real-time progress during video generation (0-100%)
  - Progress updates are broadcast via Turbo Streams
  - Visual feedback with gradient color (purple to pink)

### 3. Button State Changes
- **Generate Video → Cancel**: When video generation starts
- **Cancel → Generate Video**: When video generation is cancelled or completes
- **Download Button**: Activates when video generation completes successfully

## Technical Implementation

### Backend Components

#### 1. Project Model (`app/models/project.rb`)
```ruby
has_one_attached :video
has_many :dubbing_items
```

**Fields**:
- `video_status`: Tracks generation state ('not_started', 'generating', 'completed', 'failed', 'cancelled')
- `video_progress`: Integer (0-100) for progress tracking
- `video`: ActiveStorage attachment for generated MP4 file

#### 2. Projects Controller (`app/controllers/projects_controller.rb`)

**Actions**:
- `generate_video`: Validates all items have audio, queues `VideoGeneratorJob`
- `cancel_video`: Updates status to 'cancelled', stops generation
- `update`: Now permits `video_status` and `video_progress` parameters

#### 3. Video Generator Job (`app/jobs/video_generator_job.rb`)
- Executes video generation asynchronously
- Checks for cancellation status before processing
- Handles errors and updates status accordingly

#### 4. Video Generator Service (`app/services/video_generator_service.rb`)

**Process Flow**:
1. **Preparation (0-30%)**:
   - Downloads and prepares all images
   - Resizes images to FullHD (1920x1080)
   - Downloads audio files
   - Calculates total duration

2. **Encoding (30-80%)**:
   - Generates individual video segments (image + audio)
   - Uses FFmpeg with `libx264` codec
   - Applies stillimage tuning for better quality

3. **Concatenation (80-90%)**:
   - Combines all segments into final video
   - Uses FFmpeg concat demuxer

4. **Completion (90-100%)**:
   - Attaches final video to project
   - Updates status to 'completed'

**Broadcasting**:
- Uses `Turbo::StreamsChannel` for real-time updates
- Broadcasts progress updates to `project_#{project_id}` stream

### Frontend Components

#### 1. Video Generator Controller (`app/javascript/controllers/video_generator_controller.js`)

**Stimulus Controller**:
- Subscribes to Turbo::StreamsChannel for project updates
- Handles button clicks (generate, cancel, regenerate)
- Updates progress bar display in real-time
- Manages CSRF tokens for API requests

**Key Methods**:
- `generateVideo()`: Triggers video generation
- `cancelVideo()`: Cancels ongoing generation
- `regenerateVideo()`: Resets status and starts new generation
- `updateProgressDisplay()`: Syncs progress bar and text

#### 2. Video Controls Partial (`app/views/projects/_video_controls.html.erb`)

**States**:
- **Not Started/Failed/Cancelled**: Shows "Generate Video" button
- **Generating**: Shows progress bar and "Cancel" button
- **Completed**: Shows video player, "Download" and "Regenerate" buttons

#### 3. Turbo Stream Updates (`app/views/projects/update.turbo_stream.erb`)
- Updates project title
- Updates video controls section
- Ensures UI stays in sync with backend state

## User Flow

### Generating a Video

1. **Prerequisites**:
   - Create a project with dubbing items
   - Upload images for each item
   - Generate audio for each item (all items must have audio)

2. **Start Generation**:
   - Click "Generate Video" button
   - Button changes to "Cancel"
   - Progress bar appears and updates in real-time

3. **During Generation**:
   - Progress bar shows percentage (0-100%)
   - Status text shows "비디오 생성 중..." (Generating video...)
   - Can cancel at any time by clicking "Cancel"

4. **Completion**:
   - Status changes to "비디오 생성 완료!" (Video generation complete!)
   - Video player appears with the generated video
   - "Download" button becomes active
   - "Regenerate" button available for re-creation

### Cancelling Generation

1. Click "Cancel" button during generation
2. Status changes to "비디오 생성 취소됨" (Video generation cancelled)
3. Button returns to "Generate Video"
4. Can start over by clicking "Generate Video" again

### Downloading Video

1. Wait for generation to complete
2. Click "Download" button
3. Video downloads as `video_#{project_id}.mp4`

### Regenerating Video

1. After generation is complete, click "Regenerate" button
2. Status resets to 'not_started'
3. Video generation starts automatically
4. Existing video is replaced with new one

## Progress Tracking

### Progress Stages

| Progress Range | Stage | Description |
|---------------|-------|-------------|
| 0-30% | Preparation | Downloading and preparing media files |
| 30-80% | Encoding | Generating video segments |
| 80-90% | Concatenation | Combining segments into final video |
| 90-100% | Completion | Attaching video to project |

### Real-time Updates

- Progress updates broadcast via WebSocket (Turbo::StreamsChannel)
- UI updates automatically without page refresh
- Progress bar smooth animation (CSS transitions)

## Error Handling

### Validation Errors
- All items must have audio before generation starts
- Error message: "모든 항목에 오디오를 먼저 생성해주세요" (Please generate audio for all items first)

### Generation Errors
- If generation fails, status changes to 'failed'
- Error logged to Rails logger
- User can retry by clicking "Generate Video" again

### Cancellation
- Job checks for 'cancelled' status before processing
- Cancellation is immediate from UI perspective
- Backend cleanup happens via job completion

## Dependencies

### Required Software
- **FFmpeg**: Video encoding and processing
- **ImageMagick**: Image resizing (convert command)

### Rails Gems
- `active_storage`: File attachment management
- `turbo-rails`: Real-time updates via Turbo Streams
- `stimulus-rails`: Frontend JavaScript framework

### Database
- PostgreSQL (or SQLite for development)
- ActiveStorage tables for file storage

## Performance Considerations

### Video Generation Time
- Depends on:
  - Number of dubbing items
  - Total video duration
  - Server resources (CPU, I/O)
  - Image and audio file sizes

### Optimization Tips
1. Use optimized images (appropriate resolution)
2. Keep audio files reasonable size
3. Ensure sufficient server resources
4. Use background jobs to avoid blocking

### Storage
- Videos stored via ActiveStorage
- Configured storage location in `config/storage.yml`
- Consider cleanup of old videos to save space

## Troubleshooting

### Video Generation Not Starting
- Check that all items have audio files
- Verify FFmpeg and ImageMagick are installed
- Check Rails logs for errors

### Progress Not Updating
- Verify Turbo Streams connection
- Check browser console for JavaScript errors
- Ensure Action Cable is properly configured

### Video Not Downloading
- Verify video is attached to project
- Check ActiveStorage configuration
- Verify file permissions

## Future Enhancements

Potential improvements:
1. Preview video before generation
2. Custom video quality settings
3. Multiple video format options (WebM, AVI)
4. Progress estimation based on file sizes
5. Batch video generation for multiple projects
6. Video templates with effects/transitions

## API Endpoints

### Video Generation
```
POST /projects/:id/generate_video
```

### Cancel Generation
```
POST /projects/:id/cancel_video
```

### Download Video
```
GET /rails/active_storage/disk/...
```

## Related Files

- `app/models/project.rb` - Project model with video fields
- `app/controllers/projects_controller.rb` - Controller actions
- `app/jobs/video_generator_job.rb` - Background job
- `app/services/video_generator_service.rb` - Video generation logic
- `app/javascript/controllers/video_generator_controller.js` - Frontend controller
- `app/views/projects/_video_controls.html.erb` - Video controls UI
- `app/views/projects/update.turbo_stream.erb` - Turbo stream updates
- `app/assets/stylesheets/application.css` - Styles for video controls
- `config/routes.rb` - Route definitions
- `db/migrate/20260201141621_add_video_fields_to_projects.rb` - Database migration