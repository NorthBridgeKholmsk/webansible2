class SessionsController < ApplicationController
  skip_before_action :authenticate_user!

  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(login: params[:login])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      return_to = session.delete(:return_to)
      redirect_to (return_to.presence || root_path), notice: "Вход выполнен"
    else
      flash.now[:alert] = "Неверный логин или пароль"
      render :new, status: :unauthorized
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to new_session_path, notice: "Вы вышли из системы"
  end
end
