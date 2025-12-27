# Root controller to handle landing page and redirection for authenticated users
class RootController < ApplicationController
  def index
    if Current.user
      # Authenticated users go to wallet
      redirect_to wallet_path
    else
      # Guests see the landing page
      render "home/index"
    end
  end
end
