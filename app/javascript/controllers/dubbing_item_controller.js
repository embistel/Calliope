import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="dubbing-item"
export default class extends Controller {
  static targets = ["textarea", "thumbnail", "form", "fileInput", "dubbingControls", "progressBar", "instructButton", "instructContainer", "instructTextarea"]
  static values = {
    projectId: Number,
    itemId: Number,
    focusOnConnect: Boolean,
    instructVisible: { type: Boolean, default: false }
  }

  connect() {
    this.resize()
    
    // Check if instruct field has content and set visibility state
    if (this.hasInstructTextareaTarget && this.hasInstructButtonTarget) {
      const hasInstructContent = this.instructTextareaTarget.value.trim() !== ''
      this.instructVisibleValue = hasInstructContent
      
      if (hasInstructContent) {
        this.instructButtonTarget.classList.add('active')
      }
    }
    
    if (this.focusOnConnectValue) {
      // Use multiple attempts to ensure focus is caught after DOM updates
      const tryFocus = () => {
        if (this.hasTextareaTarget && document.activeElement !== this.textareaTarget) {
          this.textareaTarget.focus()
          return true
        }
        return false
      }

      tryFocus()
      requestAnimationFrame(tryFocus)
      setTimeout(tryFocus, 50)
      setTimeout(tryFocus, 150)
    }
  }

  resize() {
    this.textareaTarget.style.height = "auto"
    const scrollHeight = this.textareaTarget.scrollHeight
    this.textareaTarget.style.height = `${scrollHeight}px`
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      if (event.altKey) {
        // Alt+Enter toggles the instruct field
        event.preventDefault()
        this.toggleInstruct()
      } else if (!event.shiftKey) {
        event.preventDefault()
        this.saveAndCreateNext()
      }
    } else if (event.key === "Backspace" && this.textareaTarget.value === "") {
      event.preventDefault()
      this.deleteItem()
    } else if (event.key === "ArrowUp") {
      const isFirstLine = !this.textareaTarget.value.substring(0, this.textareaTarget.selectionStart).includes("\n");
      if (isFirstLine) {
        const allItems = Array.from(document.querySelectorAll('.dubbing-item'))
        const currentIndex = allItems.indexOf(this.element)
        const prevItem = allItems[currentIndex - 1]
        if (prevItem) {
          event.preventDefault()
          const textarea = prevItem.querySelector('textarea')
          if (textarea) {
            textarea.focus()
            const val = textarea.value
            textarea.value = ''
            textarea.value = val
          }
        }
      }
    } else if (event.key === "ArrowDown") {
      const isLastLine = !this.textareaTarget.value.substring(this.textareaTarget.selectionEnd).includes("\n");
      if (isLastLine) {
        const allItems = Array.from(document.querySelectorAll('.dubbing-item'))
        const currentIndex = allItems.indexOf(this.element)
        const nextItem = allItems[currentIndex + 1]
        if (nextItem) {
          event.preventDefault()
          const textarea = nextItem.querySelector('textarea')
          if (textarea) {
            textarea.focus()
            textarea.setSelectionRange(0, 0)
          }
        }
      }
    }
  }

  handleInput() {
    this.resize()
  }

  save() {
    this.formTarget.requestSubmit()
  }

  saveAndCreateNext() {
    this.save()
    this.createNextItem()
  }

  createNextItem() {
    const url = `/projects/${this.projectIdValue}/dubbing_items?insert_after=${this.itemIdValue}`
    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(response => response.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(error => console.error("Error creating next item:", error))
  }

  deleteItem() {
    const allItems = Array.from(document.querySelectorAll('.dubbing-item'))
    const currentIndex = allItems.indexOf(this.element)
    const prevId = allItems[currentIndex - 1]?.id
    const nextId = allItems[currentIndex + 1]?.id

    const hasText = this.textareaTarget.value.trim() !== ""
    const hasImage = this.thumbnailTarget.querySelector(".thumbnail-image") !== null
    const isEmpty = !hasText && !hasImage

    if (isEmpty || confirm("Are you sure you want to delete this item?")) {
      const url = `/projects/${this.projectIdValue}/dubbing_items/${this.itemIdValue}`
      fetch(url, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })
        .then(response => response.text())
        .then(html => {
          Turbo.renderStreamMessage(html)

          // Robust focus recovery identifying neighbors by ID
          const performFocus = () => {
            const target = (prevId ? document.getElementById(prevId) : null) ||
              (nextId ? document.getElementById(nextId) : null)

            if (target) {
              const textarea = target.querySelector('textarea')
              if (textarea && document.activeElement !== textarea) {
                textarea.focus()
                if (target.id === prevId) {
                  const val = textarea.value
                  textarea.value = ''
                  textarea.value = val
                } else {
                  textarea.setSelectionRange(0, 0)
                }
                return true
              }
            }
            return false
          }

          performFocus()
          requestAnimationFrame(performFocus)
          setTimeout(performFocus, 50)
          setTimeout(performFocus, 150) // One last try for slower machines/DOM updates
        })
    }
  }

  dragOver(event) {
    event.preventDefault()
    this.thumbnailTarget.classList.add("border-purple-500", "bg-purple-100/10")
  }

  dragLeave(event) {
    event.preventDefault()
    this.thumbnailTarget.classList.remove("border-purple-500", "bg-purple-100/10")
  }

  drop(event) {
    event.preventDefault()
    this.thumbnailTarget.classList.remove("border-purple-500", "bg-purple-100/10")
    if (event.dataTransfer.files && event.dataTransfer.files[0]) {
      this.uploadImage(event.dataTransfer.files[0])
    }
  }

  uploadImage(file) {
    const formData = new FormData()
    formData.append("image", file)
    formData.append("content", this.textareaTarget.value)
    formData.append("authenticity_token", document.querySelector('meta[name="csrf-token"]').content)

    const url = `/projects/${this.projectIdValue}/dubbing_items/${this.itemIdValue}/upload_image`

    fetch(url, {
      method: "POST",
      body: formData,
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(response => response.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(error => console.error("Error uploading image:", error))
  }

  playDubbing(event) {
    event.preventDefault()
    const audioUrl = event.currentTarget.dataset.audioUrl
    const audioElement = document.getElementById(`audio-${this.itemIdValue}`)

    if (audioElement) {
      audioElement.src = audioUrl
      audioElement.play()
    }
  }

  generateDubbing(event) {
    event.preventDefault()

    // Show loading state
    const button = event.currentTarget
    const btnText = button.querySelector('.btn-text')
    const generatingText = button.querySelector('.generating-text')

    btnText.style.display = 'none'
    generatingText.style.display = 'inline'
    button.disabled = true

    // Progress Bar Setup
    let progress = 0
    let progressInterval = null
    const progressFill = this.hasProgressBarTarget ? this.progressBarTarget.querySelector('.progress-bar-fill') : null

    if (this.hasProgressBarTarget && progressFill) {
      this.progressBarTarget.style.display = 'block'
      progressFill.style.animation = 'none'
      progressFill.style.width = '0%'

      // Simulate progress
      // Most of the time is spent loading the model and generating (approx 15-30s depending on text)
      progressInterval = setInterval(() => {
        if (progress < 30) {
          progress += 1 // Early stage moves faster
        } else if (progress < 60) {
          progress += 0.5 // Model loading
        } else if (progress < 95) {
          progress += 0.2 // Generation
        }

        if (progress > 95) progress = 95 // Cap at 95 until done
        progressFill.style.width = `${progress}%`
      }, 200)
    }

    // Make API call
    const url = `/projects/${this.projectIdValue}/dubbing_items/${this.itemIdValue}/generate_dubbing`

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
      .then(response => response.text())
      .then(html => {
        // Complete progress bar
        if (progressFill) {
          progressFill.style.width = '100%'
          setTimeout(() => {
            Turbo.renderStreamMessage(html)
            this.resetButtonState(button, btnText, generatingText)
          }, 300)
        } else {
          Turbo.renderStreamMessage(html)
          this.resetButtonState(button, btnText, generatingText)
        }
      })
      .catch(error => {
        console.error("Error generating dubbing:", error)
        this.resetButtonState(button, btnText, generatingText)
      })
      .finally(() => {
        if (progressInterval) clearInterval(progressInterval)
      })
  }

  resetButtonState(button, btnText, generatingText) {
    btnText.style.display = 'inline'
    generatingText.style.display = 'none'
    button.disabled = false

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.display = 'none'
    }
  }

  toggleInstruct() {
    this.instructVisibleValue = !this.instructVisibleValue
    
    if (this.instructVisibleValue) {
      this.instructContainerTarget.style.display = 'block'
      this.instructButtonTarget.classList.add('active')
      
      // Focus on the instruct textarea
      setTimeout(() => {
        if (this.hasInstructTextareaTarget) {
          this.instructTextareaTarget.focus()
          this.resizeInstructTextarea()
        }
      }, 50)
    } else {
      this.instructContainerTarget.style.display = 'none'
      this.instructButtonTarget.classList.remove('active')
      
      // Clear the instruct field when hiding
      if (this.hasInstructTextareaTarget) {
        this.instructTextareaTarget.value = ''
      }
    }
  }

  handleInstructInput() {
    this.resizeInstructTextarea()
  }

  resizeInstructTextarea() {
    if (!this.hasInstructTextareaTarget) return
    
    this.instructTextareaTarget.style.height = "auto"
    const scrollHeight = this.instructTextareaTarget.scrollHeight
    this.instructTextareaTarget.style.height = `${scrollHeight}px`
  }
}
