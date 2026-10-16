require "test_helper"

# Поиск по спискам: хосты — по имени, IP, типу, роли и ОС; организации — по имени.
class SearchTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    @organization = Organization.create!(name: "search-org-#{SecureRandom.hex(4)}")
  end

  def create_host(name:, ip:, type:, os_type:, role:)
    Host.create!(
      name: name,
      ip: ip,
      type: type,
      os_type: os_type,
      role: role,
      organization_id: @organization.id
    )
  end

  def seed_hosts
    create_host(name: "web-server-01", ip: "10.1.0.10", type: "Server", os_type: "Linux", role: ["web"])
    create_host(name: "db-server-01", ip: "10.1.0.20", type: "Server", os_type: "Linux", role: ["db"])
    create_host(name: "winbox-01", ip: "192.168.5.5", type: "WinBox", os_type: "Windows", role: ["web", "cache"])
  end

  test "список хостов без фильтров показывает всех" do
    seed_hosts
    get hosts_path
    assert_response :success
    %w[web-server-01 db-server-01 winbox-01].each { |name| assert_match name, @response.body }
  end

  test "поиск хостов по имени (частичное совпадение)" do
    seed_hosts
    get hosts_path, params: { q: "web-server" }
    assert_response :success
    assert_match "web-server-01", @response.body
    assert_no_match "db-server-01", @response.body
    assert_no_match "winbox-01", @response.body
  end

  test "поиск хостов по IP (частичное совпадение)" do
    seed_hosts
    get hosts_path, params: { q: "10.1.0" }
    assert_response :success
    assert_match "web-server-01", @response.body
    assert_match "db-server-01", @response.body
    assert_no_match "winbox-01", @response.body
  end

  test "фильтр хостов по типу" do
    seed_hosts
    get hosts_path, params: { type: "WinBox" }
    assert_response :success
    assert_match "winbox-01", @response.body
    assert_no_match "web-server-01", @response.body
    assert_no_match "db-server-01", @response.body
  end

  test "фильтр хостов по роли (роль хранится как JSON-массив)" do
    seed_hosts
    get hosts_path, params: { role: "db" }
    assert_response :success
    assert_match "db-server-01", @response.body
    assert_no_match "web-server-01", @response.body
    assert_no_match "winbox-01", @response.body

    # Роль входит в массив из нескольких значений — хост тоже находится.
    get hosts_path, params: { role: "cache" }
    assert_response :success
    assert_match "winbox-01", @response.body
  end

  test "фильтр хостов по типу ОС" do
    seed_hosts
    get hosts_path, params: { os_type: "Windows" }
    assert_response :success
    assert_match "winbox-01", @response.body
    assert_no_match "web-server-01", @response.body
    assert_no_match "db-server-01", @response.body
  end

  test "комбинация текстового запроса и фильтров сужает список" do
    seed_hosts
    get hosts_path, params: { q: "server", type: "Server", os_type: "Linux" }
    assert_response :success
    assert_match "web-server-01", @response.body
    assert_match "db-server-01", @response.body
    assert_no_match "winbox-01", @response.body

    get hosts_path, params: { q: "10.1.0", role: "db" }
    assert_response :success
    assert_match "db-server-01", @response.body
    assert_no_match "web-server-01", @response.body
  end

  test "поиск хостов без совпадений показывает пустой список" do
    seed_hosts
    get hosts_path, params: { q: "no-such-host-anywhere" }
    assert_response :success
    assert_no_match "web-server-01", @response.body
    assert_match "Хосты отсутствуют", @response.body
  end

  test "поиск организаций по имени (частичное совпадение)" do
    Organization.create!(name: "alpha-company")
    Organization.create!(name: "beta-company")

    get organizations_path, params: { q: "alpha" }
    assert_response :success
    assert_match "alpha-company", @response.body
    assert_no_match "beta-company", @response.body
  end

  test "список организаций без запроса показывает все" do
    Organization.create!(name: "gamma-company")
    Organization.create!(name: "delta-company")

    get organizations_path
    assert_response :success
    assert_match "gamma-company", @response.body
    assert_match "delta-company", @response.body
  end
end