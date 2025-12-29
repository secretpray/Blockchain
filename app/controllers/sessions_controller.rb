# frozen_string_literal: true

class SessionsController < ApplicationController
  # IP-based rate limiting (SIWE verify is expensive)
  rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, only: :create

  def create
    if eth_address_invalid?(eth_address)
      @error_message = "Invalid address format"
      return respond_to_authentication_error
    end

    if auth_service.authenticate
      sign_in_user(auth_service.user)
    else
      @error_message = auth_service.errors.first
      respond_to_authentication_error
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def eth_address_invalid?(address)
    !address.match?(/\A0x[a-f0-9]{40}\z/)
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

  def eth_address
    @eth_address ||= eth_address_param
  end

  def auth_service
    @auth_service ||= SiweAuthenticationService.new(
      eth_address:,
      message: siwe_message_param,
      signature: signature_param,
      request:
    )
  end

  def sign_in_user(user)
    session[:user_id] = user.id

    respond_to do |format|
      notice = "Successfully signed in"
      format.turbo_stream do
        flash.now[:notice] = notice
      end
      format.html { redirect_to wallet_path, notice: }
    end
  end

  def respond_to_authentication_error
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = @error_message
        render :create, status: :unprocessable_entity
      end
      format.html do
        redirect_back fallback_location: root_path, alert: @error_message
      end
    end
  end
end
