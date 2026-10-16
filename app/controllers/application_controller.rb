class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!
  helper_method :current_user

  helper do
    def page_title
      content_for(:page_title) || "WebAnsible"
    end
  end

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    return if current_user
    session[:return_to] = request.fullpath if request.get?
    redirect_to new_session_path, alert: "Необходимо войти в систему"
  end

  def require_admin!
    redirect_to root_path, alert: "У вас нет прав" unless current_user&.admin?
  end

  def require_editor!
    redirect_to root_path, alert: "У вас нет прав" unless current_user&.editor?
  end
end
