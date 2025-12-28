# frozen_string_literal: true

class SessionsController < ApplicationController
  # IP-based rate limiting (SIWE verify is expensive)
  rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, only: :create

  def new; end

  def create
    address = eth_address_param
    return render_invalid("Invalid address format") unless valid_eth_address?(address)

    auth_service = SiweAuthenticationService.new(
      eth_address: address,
      message: siwe_message_param,
      signature: signature_param,
      request:
    )

    if auth_service.authenticate
      # User is created inside auth_service after successful verification
      sign_in_user(auth_service.user)
    else
      render_invalid(auth_service.errors.first)
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def valid_eth_address?(address)
    address.match?(/\A0x[a-f0-9]{40}\z/)
  end

  def eth_address_param
    params.require(:eth_address).to_s.downcase
  end

  def siwe_message_param
    params.require(:message)
  end

  def signature_param
    params.require(:signature)
  end

  def sign_in_user(user)
    session[:user_id] = user.id
    redirect_to wallet_path, notice: "Successfully signed in"
  end

  def render_invalid(msg)
    flash.now[:alert] = msg
    render :new, status: :unprocessable_entity
  end
end
