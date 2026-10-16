# Пользователь приложения (вход в UI).
#
# Аутентификация — has_secure_password (bcrypt-хэш в password_digest);
# сессия хранит только user_id (см. ApplicationController#current_user).
class User < ApplicationRecord
  has_secure_password

  validates :login, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 2 }, allow_nil: true

  # Роль пользователя:
  #   admin  — полный доступ (пользователи, настройки, синхронизация Zabbix);
  #   editor — работа с данными (организации, хосты, плейбуки, запуски).
  enum role: { admin: "admin", editor: "editor" }

  def full_name
    login
  end
end
