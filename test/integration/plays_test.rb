require "test_helper"

# Плеи: типа и привязки к организациям нет — создание работает без них,
# в списке и форме соответствующих полей нет.
class PlaysTest < ActionDispatch::IntegrationTest
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

  test "плей создаётся без типа и организации" do
    name = "pl-#{SecureRandom.hex(3)}"
    post plays_path, params: { play: { name: name, os_type: "ubuntu", content: "---\n" } }
    assert_response :redirect
    pl = Play.find_by(name: name)
    assert_not_nil pl
  end

  test "список и форма не содержат типа и организации" do
    get plays_path
    assert_response :success
    assert_no_match(%(name="play[type]"), @response.body)
    assert_no_match(/organization_id/, @response.body)

    get new_play_path
    assert_response :success
    assert_no_match(%(name="play[type]"), @response.body)
    assert_no_match(%(name="play[organization_id]"), @response.body)
  end
end
