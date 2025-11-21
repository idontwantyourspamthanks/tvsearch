class AdminSessionsController < ApplicationController
  def new
    redirect_to admin_root_path, notice: "Already signed in." if current_admin_user
  end

  def create
    admin = AdminUser.find_by(email: params[:email].to_s.downcase)

    if admin&.authenticate(params[:password])
      session[:admin_user_id] = admin.id
      redirect_to admin_root_path, notice: "Signed in as #{admin.email}."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end
end
