require "test_helper"

# Плейбуки: типа и привязки к организациям нет — создание работает без них,
# в списке и форме соответствующих полей нет.
class PlaybooksTest < ActionDispatch::IntegrationTest
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

  test "плейбук создаётся без типа и организации" do
    name = "pb-#{SecureRandom.hex(3)}"
    post playbooks_path, params: { playbook: { name: name, os_type: "ubuntu", content: "---\n" } }
    assert_response :redirect
    pb = Playbook.find_by(name: name)
    assert_not_nil pb
  end

  test "список и форма не содержат типа и организации" do
    get playbooks_path
    assert_response :success
    assert_no_match(/playbook_type/, @response.body)
    assert_no_match(/organization_id/, @response.body)

    get new_playbook_path
    assert_response :success
    assert_no_match(/playbook_type/, @response.body)
    assert_no_match(%(name="playbook[organization_id]"), @response.body)
  end
end
