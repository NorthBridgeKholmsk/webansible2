require "test_helper"

# Страница настроек («Приложение»): остались только рабочие параметры —
# тема (Общие) и подключение Zabbix; мёртвые поля удалены.
class SettingsPageTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect
  end

  test "на странице настроек нет мёртвых полей и есть рабочие" do
    get settings_path
    assert_response :success
    # Мёртвые параметры удалены из формы.
    refute_includes response.body, "Название приложения"
    refute_includes response.body, "Путь к ansible-playbook"
    refute_includes response.body, "Пользователь по умолчанию"
    refute_includes response.body, "Таймаут (сек)"
    # Рабочие параметры на месте.
    assert_includes response.body, "Тема"
    assert_includes response.body, "Адрес Zabbix"
  end
end
