# frozen_string_literal: true

class User < ApplicationRecord
  include Authenticatable

  before_validation :normalize_eth_address

  validates :eth_address,
    presence: { message: "Please connect your wallet" },
    uniqueness: { case_sensitive: false, message: "This wallet is already registered. Please use a different wallet or sign in." },
    format: { with: /\A0x[a-f0-9]{40}\z/, message: "Invalid Ethereum address format" }
  validates :eth_nonce, presence: true, uniqueness: true

  def display_address
    "#{eth_address[0..5]}...#{eth_address[-4..]}"
  end

  private

  def normalize_eth_address
    self.eth_address = eth_address&.downcase
  end
end
