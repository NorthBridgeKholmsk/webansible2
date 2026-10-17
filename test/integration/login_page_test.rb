require "test_helper"

# Страница логина: без подсказки о пароле по умолчанию,
# без левого меню и верхней панели (режим full_page).
class LoginPageTest < ActionDispatch::IntegrationTest
  test "форма логина не показывает пароль по умолчанию и сайдбар" do
    get new_session_path
    assert_response :success
    refute_includes response.body, "Логин по умолчанию"
    refute_includes response.body, 'id="sidebar"'
    # Сама карточка входа на месте.
    assert_includes response.body, "Войдите в систему"
  end
end
