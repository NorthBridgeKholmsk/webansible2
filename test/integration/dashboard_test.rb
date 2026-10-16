# frozen_string_literal: true

require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure a seeded admin exists for the test DB.
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
  end

  test "GET / renders the dashboard (content_for fix)" do
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect
    get root_path
    assert_response :success
    # The layout uses content_for(:page_title) to render the <title>.
    assert_match(/WebAnsible/, @response.body)
    # The DashboardController#index sets content_for(:page_title) { "Главная" };
    # it must reach the layout (proving content_for works after the fix).
    assert_match(/Главная/, @response.body)
  end
end
