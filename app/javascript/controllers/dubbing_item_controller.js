import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="dubbing-item"
export default class extends Controller {
  static targets = ["textarea", "thumbnail", "form", "fileInput"]
  static values = {
    projectId: Number,
    itemId: Number,
    focusOnConnect: Boolean
  }

  connect() {
    this.resize()
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
      if (!event.shiftKey) {
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
}
