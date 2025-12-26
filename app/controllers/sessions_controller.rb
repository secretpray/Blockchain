class SessionsController < ApplicationController
  before_action :load_user, only: :create

  def new; end

  def create
    return render_invalid("Unknown account") unless @user
    return if siwe_payload_invalid?

    sign_in_user(@user)
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def load_user
    @address = eth_address_param
    @user = User.find_by(eth_address: @address)
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

  def siwe_payload
    {
      message: siwe_message_param,
      signature: signature_param,
      address: @address,
      user: @user
    }
  end

  def siwe_payload_invalid?
    !verify_siwe!(**siwe_payload)
  end

  # Verifies SIWE payload (format + signature + nonce + domain + time)
  # nonce + time checks are performed inside `verify` (Expired/NotValid/InvalidSignature too)
  def verify_siwe!(message:, signature:, address:, user:)
    siwe = Siwe::Message.from_message(message)

    # Ensure the address in the SIWE message matches the form address
    return render_invalid("Address mismatch") unless siwe.address.to_s.downcase == address

    expected_domain = request.host_with_port
    expected_nonce = user.eth_nonce
    now_utc = Time.current.utc.iso8601

    siwe.verify(signature, expected_domain, now_utc, expected_nonce)

    true
  rescue Siwe::ExpiredMessage
    render_invalid("Signature expired")
    false
  rescue Siwe::NotValidMessage
    render_invalid("Message not valid yet")
    false
  rescue Siwe::InvalidSignature
    render_invalid("Invalid signature")
    false
  rescue Siwe::InvalidDomain, Siwe::DomainMismatch
    render_invalid("Domain mismatch")
    false
  rescue Siwe::NonceMismatch, Siwe::InvalidNonce
    render_invalid("Invalid nonce")
    false
  rescue Siwe::UnableToParseMessage
    render_invalid("Unable to parse SIWE message")
    false
  rescue StandardError => e
    Rails.logger.warn("SIWE verify failed: #{e.class}: #{e.message}")
    render_invalid("Invalid SIWE payload")
    false
  end

  def sign_in_user(user)
    session[:user_id] = user.id
    user.rotate_nonce! # Prevent replay attacks by rotating nonce

    redirect_to root_path, notice: "Signed in"
  end

  def render_invalid(msg)
    flash.now[:alert] = msg
    render :new, status: :unprocessable_content
  end
end
