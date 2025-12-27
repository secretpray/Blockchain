# Controller to manage wallet-related actions
class WalletController < ApplicationController
  before_action :require_authentication

  def show
    @user = Current.user
  end

  private

  def require_authentication
    return if Current.user

    redirect_to new_session_path, alert: "Please connect your wallet to continue"
  end
end
