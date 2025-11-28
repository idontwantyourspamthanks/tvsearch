class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_admin_user

  private

  def current_admin_user
    @current_admin_user ||= AdminUser.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
  end

  def require_admin!
    return if current_admin_user

    respond_to do |format|
      format.json do
        render json: { error: "Please log in to continue." }, status: :unauthorized
      end
      format.any do
        redirect_to admin_login_path, alert: "Please log in to continue."
      end
    end
  end
end
