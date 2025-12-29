// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "pwa"

// Custom Turbo Stream Actions
// StreamActions is available via the global Turbo object after importing @hotwired/turbo-rails
// Custom Turbo Stream Action: <turbo-stream action="redirect" url="...">
Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url")
  if (!url) return

  const frameAttr = this.getAttribute("frame")
  const actionAttr = this.getAttribute("action")

  const frame = (frameAttr && frameAttr.trim() !== "") ? frameAttr : "_top"
  const action = (actionAttr && actionAttr.trim() !== "") ? actionAttr : "advance"

  // (опционально) минимальная валидация action
  const allowedActions = new Set(["advance", "replace", "restore"])
  const finalAction = allowedActions.has(action) ? action : "advance"

  Turbo.visit(url, { frame, action: finalAction })
}
