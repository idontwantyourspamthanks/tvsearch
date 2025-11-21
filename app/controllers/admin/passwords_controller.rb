class Admin::PasswordsController < ApplicationController
  before_action :require_admin!

  def edit; end

  def update
    unless current_admin_user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      return render :edit, status: :unprocessable_entity
    end

    if current_admin_user.update(password_params)
      redirect_to admin_root_path, notice: "Password updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
