# frozen_string_literal: true

# Authentication security methods for User model
# Provides nonce management, rate limiting, and attempt tracking
module Authenticatable
  extend ActiveSupport::Concern

  NONCE_TTL = 10.minutes
  MAX_AUTH_ATTEMPTS = 3
  RATE_LIMIT_WINDOW = 1.minute

  included do
    scope :unverified, -> { where(verified: false) }
    scope :stale_unverified, -> { unverified.where("created_at < ?", 7.days.ago) }
    scope :with_stale_nonces, -> { where("nonce_issued_at < ? OR nonce_issued_at IS NULL", NONCE_TTL.ago) }
  end

  # Check if nonce is still valid (within TTL)
  def nonce_valid?
    nonce_issued_at && nonce_issued_at > NONCE_TTL.ago
  end

  # Check if user can attempt authentication (rate limiting)
  def can_attempt_auth?
    return true if last_auth_attempt_at.nil?
    return true if last_auth_attempt_at < RATE_LIMIT_WINDOW.ago

    auth_attempts_count < MAX_AUTH_ATTEMPTS
  end

  # Record authentication attempt for rate limiting
  def record_auth_attempt!
    if last_auth_attempt_at && last_auth_attempt_at > RATE_LIMIT_WINDOW.ago
      increment!(:auth_attempts_count)
    else
      update!(auth_attempts_count: 1, last_auth_attempt_at: Time.current)
    end
  end

  # Rotate nonce and reset security counters
  def rotate_nonce!
    update!(
      eth_nonce: Siwe::Util.generate_nonce,
      nonce_issued_at: Time.current,
      auth_attempts_count: 0,
      last_auth_attempt_at: nil
    )
  end

  # Check if nonce was already used (cache-based, optional)
  def nonce_used?
    Rails.cache.read(nonce_used_cache_key).present?
  rescue
    false # Graceful degradation if cache unavailable
  end

  # Mark nonce as used in cache
  def mark_nonce_as_used!
    Rails.cache.write(nonce_used_cache_key, true, expires_in: NONCE_TTL)
  rescue => e
    Rails.logger.warn("Cache unavailable for nonce marking: #{e.message}")
  end

  private

  def nonce_used_cache_key
    "nonce_used:#{eth_address}:#{eth_nonce}"
  end
end
