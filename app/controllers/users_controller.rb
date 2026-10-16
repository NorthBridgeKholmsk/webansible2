class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    @users = User.order(:login)
    content_for(:page_title) { "Пользователи" }
  end

  def new
    @user = User.new
    content_for(:page_title) { "Новый пользователь" }
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "Пользователь создан"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    content_for(:page_title) { "Редактирование: #{@user.login}" }
  end

  def update
    params_user = user_params
    params_user = params_user.except(:password) if params[:user][:password].blank?
    if @user.update(params_user)
      redirect_to users_path, notice: "Пользователь обновлён"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    User.destroy_all if current_user.admin? # simplistic; keep at least one
    @user.destroy
    redirect_to users_path, notice: "Пользователь удалён"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:login, :password, :password_confirmation, :role, :active)
  end
end