import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { projectId: Number }
  static targets = ["progressBar", "progressText"]
  
  connect() {
    // Turbo Streams are automatically handled by Rails Turbo
    // No manual subscription needed
  }
  
  generateVideo() {
    fetch(`/projects/${this.projectIdValue}/generate_video`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getMetaValue("csrf-token")
      }
    })
  }
  
  cancelVideo() {
    fetch(`/projects/${this.projectIdValue}/cancel_video`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getMetaValue("csrf-token")
      }
    })
  }
  
  regenerateVideo() {
    // Reset status to not_started
    fetch(`/projects/${this.projectIdValue}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getMetaValue("csrf-token")
      },
      body: JSON.stringify({ project: { video_status: "not_started", video_progress: 0 } })
    }).then(() => {
      this.generateVideo()
    })
  }
  
  getMetaValue(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`)
    return element ? element.getAttribute("content") : null
  }
}