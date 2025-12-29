# frozen_string_literal: true

# Custom Turbo Stream Actions Helper
module TurboStreamActionsHelper
  # Custom Turbo Stream Actions
  # These will automatically be made available on the `turbo_stream` helper
  # Add the matching StreamAction in `app/javascript/application.js`
  module CustomTurboStreamActions
    # render turbo_stream: turbo_stream.redirect(wallet_path)
    # render turbo_stream: turbo_stream.redirect(wallet_path, frame: "_self", action: "replace")
    #
    # Options:
    #   frame: "_top" (default) | "_self" | any frame name
    #   action: "advance" (default) | "replace" | "restore"
    def redirect(url, frame: "_top", action: "advance")
      turbo_stream_action_tag("redirect", url:, frame:, action:)
    end
  end

  Turbo::Streams::TagBuilder.prepend(CustomTurboStreamActions)
end
