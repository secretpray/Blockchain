# frozen_string_literal: true

# Service object for SIWE (Sign-In With Ethereum) authentication
# Cache-based implementation - no User creation until successful verification
class SiweAuthenticationService
  attr_reader :eth_address, :message, :signature, :request, :errors, :user

  NONCE_TTL = 10.minutes
  MESSAGE_EXPIRATION = 5.minutes # Maximum age of signed message

  # Allowed Chain IDs (EIP-155)
  # 1 = Ethereum Mainnet
  # 5 = Goerli Testnet (deprecated)
  # 11155111 = Sepolia Testnet
  # 137 = Polygon Mainnet
  # 80001 = Polygon Mumbai Testnet
  # 31337 = Hardhat local network (for development)
  ALLOWED_CHAIN_IDS = [ 1, 5, 11155111, 137, 80001, 31337 ].freeze

  def initialize(eth_address:, message:, signature:, request:)
    @eth_address = eth_address.downcase
    @message = message
    @signature = signature
    @request = request
    @errors = []
    @user = nil
  end

  # Perform full authentication flow with security checks
  def authenticate
    Rails.logger.info("Authentication attempt for address: #{@eth_address}")

    return false unless perform_security_checks
    return false unless verify_signature

    # CRITICAL: Create User ONLY after successful verification
    create_or_find_user
    invalidate_nonce

    Rails.logger.info("Authentication successful for address: #{@eth_address}")
    true
  end

  private

  # Security checks before signature verification
  def perform_security_checks
    # 1. Check if nonce exists in cache
    cached_nonce = Rails.cache.read(nonce_cache_key)
    unless cached_nonce
      @errors << "Nonce not found or expired. Please request a new one."
      return false
    end

    # 2. Check if nonce was already used (one-time use)
    if nonce_already_used?(cached_nonce)
      @errors << "Nonce already used. Please request a new one."
      Rails.logger.warn("Nonce reuse attempt detected for address: #{@eth_address}")
      return false
    end

    # 3. Parse SIWE message and verify nonce matches
    begin
      siwe = Siwe::Message.from_message(message)
      unless siwe.nonce == cached_nonce
        @errors << "Nonce mismatch. Please try again."
        return false
      end

      @siwe_message = siwe
      @cached_nonce = cached_nonce
    rescue Siwe::UnableToParseMessage
      @errors << "Unable to parse SIWE message. Please try again."
      return false
    end

    # 4. Mark nonce as used before verification (prevent concurrent attempts)
    mark_nonce_as_used(@cached_nonce)

    true
  end

  # Verify SIWE signature and message
  def verify_signature
    # 1. Verify address matches
    unless @siwe_message.address.to_s.downcase == @eth_address
      @errors << "Address mismatch"
      return false
    end

    # 2. Verify Chain ID is allowed (EIP-155 compliance)
    chain_id = @siwe_message.chain_id.to_i
    unless ALLOWED_CHAIN_IDS.include?(chain_id)
      @errors << "Unsupported chain. Please switch to a supported network."
      Rails.logger.warn("Unsupported Chain ID: #{chain_id}. Allowed: #{ALLOWED_CHAIN_IDS.join(', ')}")
      return false
    end

    # 3. Verify message timestamp is not too old
    if @siwe_message.issued_at
      issued_at = Time.parse(@siwe_message.issued_at)
      if Time.current - issued_at > MESSAGE_EXPIRATION
        @errors << "Signature expired. Please sign a new message."
        Rails.logger.warn("Message too old: issued at #{issued_at}, current time #{Time.current}")
        return false
      end
    end

    # 4. Verify signature
    @siwe_message.verify(
      @signature,
      @request.host_with_port,
      Time.current.utc.iso8601,
      @cached_nonce
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
  rescue StandardError => e
    Rails.logger.error("SIWE verification failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    @errors << "Authentication failed. Please try again."
    false
  end

  def create_or_find_user
    @user = User.find_or_create_by!(eth_address: @eth_address)
    Rails.logger.info("User found or created: #{@user.id} (#{@eth_address})")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create user: #{e.message}")
    @errors << "Failed to create user account."
    false
  end

  def invalidate_nonce
    # Remove nonce from cache after successful authentication
    Rails.cache.delete(nonce_cache_key)
    Rails.cache.delete(nonce_used_cache_key(@cached_nonce))
  end

  def nonce_cache_key
    "siwe_nonce:#{@eth_address}"
  end

  def nonce_used_cache_key(nonce)
    "nonce_used:#{@eth_address}:#{nonce}"
  end

  def nonce_already_used?(nonce)
    Rails.cache.read(nonce_used_cache_key(nonce)).present?
  rescue
    false # Graceful degradation if cache unavailable
  end

  def mark_nonce_as_used(nonce)
    Rails.cache.write(nonce_used_cache_key(nonce), true, expires_in: NONCE_TTL)
  rescue => e
    Rails.logger.warn("Cache unavailable for nonce marking: #{e.message}")
  end
end
