import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "text"]

    edit() {
        this.element.classList.add("editing")
        this.inputTarget.focus()
        // Move cursor to end
        const val = this.inputTarget.value
        this.inputTarget.value = ""
        this.inputTarget.value = val
    }

    save() {
        if (this.element.classList.contains("editing")) {
            this.element.classList.remove("editing")
            this.element.querySelector("form").requestSubmit()
        }
    }

    handleKeydown(event) {
        if (event.key === "Enter") {
            event.preventDefault()
            this.save()
        } else if (event.key === "Escape") {
            this.element.classList.remove("editing")
            this.inputTarget.value = this.textTarget.textContent.trim()
        }
    }
}
