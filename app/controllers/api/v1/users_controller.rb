# frozen_string_literal: true

class Api::V1::UsersController < ApplicationController
  skip_forgery_protection

  # Rate limiting to prevent nonce farming
  # Uses IP:address combination (operation is cheap)
  rate_limit to: 30, within: 1.minute, only: :show, by: -> {
    "#{request.remote_ip}:#{params[:eth_address].to_s.downcase}"
  }

  def index
    render json: nil
  end

  def show
    address = params[:eth_address].to_s.downcase

    unless address.match?(/\A0x[a-f0-9]{40}\z/)
      return render json: { error: "Invalid address format" }, status: :bad_request
    end

    user = User.find_or_create_by(eth_address: address) do |u|
      u.eth_nonce = Siwe::Util.generate_nonce
      u.nonce_issued_at = Time.current
      u.auth_attempts_count = 0
      u.verified = false
    end

    # Rotate nonce for existing users (new challenge per request)
    user.rotate_nonce! if user.persisted? && !user.previously_new_record?

    render json: { eth_nonce: user.eth_nonce }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
