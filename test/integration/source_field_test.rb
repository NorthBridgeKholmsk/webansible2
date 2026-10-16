require "test_helper"

# Поле «Источник» в UI: создаётся только как manual, через params не подделать
# (поле не в permit), в формах нередактируемое, в списках и на страницах видно.
class SourceFieldTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    @organization = Organization.create!(name: "org-#{SecureRandom.hex(4)}")
  end

  def host_params(name)
    {
      name: name,
      ip: "10.8.0.#{rand(2..254)}",
      type: "WorkStation",
      os_type: "Windows",
      role: ["1С"],
      organization_id: @organization.id
    }
  end

  test "хост из UI создаётся с source manual; подделка через params игнорируется" do
    name = "ws-src-#{SecureRandom.hex(3)}"
    post hosts_path, params: { host: host_params(name).merge(source: "zabbix") }
    assert_response :redirect

    host = Host.find_by(name: name)
    assert_not_nil host
    assert_equal Host::SOURCE_MANUAL, host.source
  end

  test "обновление хоста не меняет source" do
    host = Host.create!(host_params("ws-patch-#{SecureRandom.hex(3)}"))
    patch host_path(host), params: { host: host_params(host.name).merge(source: "zabbix") }
    assert_response :redirect

    assert_equal Host::SOURCE_MANUAL, host.reload.source
  end

  test "организация из UI создаётся с source manual; подделка через params игнорируется" do
    name = "org-src-#{SecureRandom.hex(3)}"
    post organizations_path, params: { organization: { name: name, source: "zabbix" } }
    assert_response :redirect

    org = Organization.find_by(name: name)
    assert_not_nil org
    assert_equal Organization::SOURCE_MANUAL, org.source
  end

  test "список хостов показывает источник; форма не даёт его редактировать" do
    manual_host = Host.create!(host_params("ws-manual-#{SecureRandom.hex(3)}"))
    zabbix_host = Host.create!(host_params("ws-zbx-#{SecureRandom.hex(3)}").merge(source: Host::SOURCE_ZABBIX))

    get hosts_path
    assert_response :success
    assert_match(/Вручную/, @response.body)
    assert_match(/Zabbix/, @response.body)

    get edit_host_path(manual_host)
    assert_response :success
    # В форме нет редактируемого поля source (disabled-инпут без name).
    assert_no_match(/name="host\[source\]"/, @response.body)
    assert_match(/Вручную/, @response.body)

    get host_path(zabbix_host)
    assert_response :success
    assert_match(/Zabbix/, @response.body)
  end

  test "список организаций показывает источник; форма не даёт его редактировать" do
    manual_org = Organization.create!(name: "org-manual-#{SecureRandom.hex(3)}")
    zabbix_org = Organization.create!(name: "org-zbx-#{SecureRandom.hex(3)}", source: Organization::SOURCE_ZABBIX)

    get organizations_path
    assert_response :success
    assert_match(/Вручную/, @response.body)
    assert_match(/Zabbix/, @response.body)

    get edit_organization_path(manual_org)
    assert_response :success
    assert_no_match(/name="organization\[source\]"/, @response.body)
    assert_match(/Вручную/, @response.body)

    get organization_path(zabbix_org)
    assert_response :success
    assert_match(/Zabbix/, @response.body)
  end
end
