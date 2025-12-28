# frozen_string_literal: true

# Service object for SIWE (Sign-In With Ethereum) authentication
# Handles message verification, security checks, and user session creation
class SiweAuthenticationService
  attr_reader :user, :message, :signature, :request, :errors

  def initialize(user:, message:, signature:, request:)
    @user = user
    @message = message
    @signature = signature
    @request = request
    @errors = []
  end

  # Perform full authentication flow with security checks
  def authenticate
    return false unless perform_security_checks
    return false unless verify_signature

    mark_nonce_used
    verify_user
    true
  end

  private

  # Security checks before signature verification
  def perform_security_checks
    unless user.can_attempt_auth?
      @errors << "Too many authentication attempts. Please wait #{Authenticatable::RATE_LIMIT_WINDOW.inspect}."
      return false
    end

    unless user.nonce_valid?
      user.rotate_nonce!
      @errors << "Nonce expired. Please refresh and try again."
      return false
    end

    if user.nonce_used?
      @errors << "Nonce already used. Please request a new one."
      return false
    end

    user.record_auth_attempt!
    true
  end

  # Verify SIWE signature and message
  def verify_signature
    siwe = Siwe::Message.from_message(message)

    unless siwe.address.to_s.downcase == user.eth_address
      @errors << "Address mismatch"
      return false
    end

    siwe.verify(
      signature,
      request.host_with_port,
      Time.current.utc.iso8601,
      user.eth_nonce
    )

    true
  rescue Siwe::ExpiredMessage
    @errors << "Signature expired. Please sign a new message."
    false
  rescue Siwe::NotValidMessage
    @errors << "Message not valid yet. Check your system time."
    false
  rescue Siwe::InvalidSignature
    @errors << "Invalid signature. Please try signing again."
    false
  rescue Siwe::InvalidDomain, Siwe::DomainMismatch
    @errors << "Domain mismatch. Please refresh and try again."
    false
  rescue Siwe::NonceMismatch, Siwe::InvalidNonce
    @errors << "Invalid nonce. Please refresh and request a new nonce."
    false
  rescue Siwe::UnableToParseMessage
    @errors << "Unable to parse SIWE message. Please try again."
    false
  rescue StandardError => e
    Rails.logger.error("SIWE verification failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    @errors << "Authentication failed. Please try again."
    false
  end

  def mark_nonce_used
    user.mark_nonce_as_used!
  end

  def verify_user
    user.update!(verified: true) unless user.verified?
  end
end
