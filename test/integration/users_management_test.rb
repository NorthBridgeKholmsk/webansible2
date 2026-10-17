require "test_helper"

# Управление пользователями: удаление одного пользователя не затрагивает остальных.
class UsersManagementTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    @other1 = User.create!(login: "user-#{SecureRandom.hex(3)}", password: "secret123", role: "editor")
    @other2 = User.create!(login: "user-#{SecureRandom.hex(3)}", password: "secret123", role: "editor")
  end

  test "удаление одного пользователя не удаляет остальных" do
    delete user_path(@other1)
    assert_response :redirect
    assert_nil User.find_by(id: @other1.id), "выбранный пользователь должен быть удалён"
    assert User.exists?(@other2.id), "остальные пользователи должны остаться"
    assert User.exists?(User.find_by(login: "admin").id)

    get users_path
    assert_response :success
    assert_includes response.body, @other2.login
  end

  test "нельзя удалить собственный аккаунт" do
    admin = User.find_by(login: "admin")
    delete user_path(admin)
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Нельзя удалить собственный аккаунт"
    assert User.exists?(admin.id), "собственный аккаунт должен остаться"
  end
end
