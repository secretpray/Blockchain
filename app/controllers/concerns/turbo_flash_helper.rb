# frozen_string_literal: true

# Helper module for rendering turbo flash messages
module TurboFlashHelper
  extend ActiveSupport::Concern

  included do
    helper_method :render_turbo_flash
  end

  def render_turbo_flash
    turbo_stream.prepend("flash-section", partial: "layouts/shared/flash_messages")
  end
end
