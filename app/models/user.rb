# User model with Ethereum address and nonce management
class User < ApplicationRecord
  before_validation :normalize_eth_address

  validates :eth_address,
    presence: { message: "Please connect your wallet" },
    uniqueness: { case_sensitive: false, message: "This wallet is already registered. Please use a different wallet or sign in." },
    format: { with: /\A0x[a-f0-9]{40}\z/, message: "Invalid Ethereum address format" }
  validates :eth_nonce, presence: true, uniqueness: true

  def rotate_nonce!
    update!(eth_nonce: Siwe::Util.generate_nonce)
  end

  # Helper method to display shortened address
  def display_address
    "#{eth_address[0..5]}...#{eth_address[-4..]}"
  end

  private

  def normalize_eth_address
    self.eth_address = eth_address&.downcase
  end
end
