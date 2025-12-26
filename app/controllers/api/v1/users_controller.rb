class Api::V1::UsersController < ApplicationController
  skip_forgery_protection

  # Prevent get listing all users or exposing nonces of unknown addresses
  def index
    render json: nil
  end

  def show
    address = params[:eth_address].to_s.downcase
    # [TODO] Move regex to model validation
    return render json: nil unless address.match?(/\A0x[a-f0-9]{40}\z/)

    user = User.find_by(eth_address: address)
    return render json: nil unless user

    render json: { eth_nonce: user.eth_nonce }
  end
end
