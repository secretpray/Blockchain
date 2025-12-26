class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.eth_nonce = Siwe::Util.generate_nonce

    if @user.save
      redirect_to new_session_path, notice: "Account created. Please log in with your wallet."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:eth_address)
  end
end
