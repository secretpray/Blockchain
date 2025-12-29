# frozen_string_literal: true

class Api::V1::UsersController < ApplicationController
  skip_forgery_protection

  # Rate limiting to prevent nonce farming
  # Uses IP:address combination (operation is cheap)
  rate_limit to: 30, within: 1.minute, only: :show, by: -> {
    "#{request.remote_ip}:#{params[:eth_address].to_s.downcase}"
  }

  def show
    address = params[:eth_address].to_s.downcase

    unless address.match?(/\A0x[a-f0-9]{40}\z/)
      return render json: { error: "Invalid address format" }, status: :bad_request
    end

    # Generate nonce and store in cache (NOT in database)
    nonce = SecureRandom.hex(16)
    cache_key = "siwe_nonce:#{address}"

    # Store with 10 minute TTL (auto-expiration)
    Rails.cache.write(cache_key, nonce, expires_in: 10.minutes)

    render json: { eth_nonce: nonce }
  end
end
