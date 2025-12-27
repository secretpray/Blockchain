import { Controller } from "@hotwired/stimulus"

// Notification controller to manage flash message display and auto-hide
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 }
  }

  connect() {
    this.show()
    this.timeout = setTimeout(() => {
      this.hide()
    }, this.delayValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  show() {
    // Remove hidden class and trigger animation
    this.element.classList.remove('hidden')

    // Force reflow to ensure animation triggers
    this.element.offsetHeight

    // Add show animation classes
    this.element.classList.remove('opacity-0', 'translate-y-2', 'translate-x-full')
    this.element.classList.add('opacity-100', 'translate-y-0', 'translate-x-0')
  }

  hide() {
    // Add hide animation classes
    this.element.classList.remove('opacity-100', 'translate-y-0', 'translate-x-0')
    this.element.classList.add('opacity-0', 'translate-x-full')

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300) // Match transition duration
  }
}
