require "test_helper"

# Переменные хостов и организаций в формах редактирования:
# - если переменных нет, список пуст (строк по умолчанию не создаётся);
# - сохранение без переменных работает;
# - добавление/удаление переменных через variables_attributes.
class HostsOrganizationsVariablesTest < ActionDispatch::IntegrationTest
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
      ip: "10.0.0.#{rand(2..254)}",
      type: "WorkStation",
      os_type: "Windows",
      role: ["1С"],
      organization_id: @organization.id
    }
  end

  test "форма нового хоста не содержит строк переменных по умолчанию" do
    get new_host_path
    assert_response :success
    assert_no_match(/variables_attributes/, @response.body)
    assert_match(%(data-variable-prefix="host"), @response.body)
  end

  test "форма новой организации не содержит строк переменных по умолчанию" do
    get new_organization_path
    assert_response :success
    assert_no_match(/variables_attributes/, @response.body)
    assert_match(%(data-variable-prefix="organization"), @response.body)
  end

  test "форма редактирования хоста без переменных показывает пустой список" do
    host = Host.create!(host_params("ws-empty-#{SecureRandom.hex(3)}"))
    get edit_host_path(host)
    assert_response :success
    assert_no_match(/variables_attributes/, @response.body)
  end

  test "форма редактирования хоста показывает существующие переменные" do
    host = Host.create!(host_params("ws-vars-#{SecureRandom.hex(3)}"))
    Variable.create!(variableable: host, name: "env", value: "prod")
    Variable.create!(variableable: host, name: "site", value: "ru")

    get edit_host_path(host)
    assert_response :success
    rows = @response.body.scan(/name="host\[variables_attributes\]\[\d+\]\[name\]"/).size
    assert_equal 2, rows
  end

  test "хост можно создать без переменных" do
    name = "ws-new-#{SecureRandom.hex(3)}"
    post hosts_path, params: { host: host_params(name) }
    assert_response :redirect
    host = Host.find_by(name: name)
    assert_not_nil host
    assert_equal 0, host.variables.count
  end

  test "хост можно обновить без переменных — существующие не трогаются" do
    host = Host.create!(host_params("ws-keep-#{SecureRandom.hex(3)}"))
    Variable.create!(variableable: host, name: "env", value: "prod")

    patch host_path(host), params: { host: host_params(host.name) }
    assert_response :redirect
    assert_equal 1, host.reload.variables.count
  end

  test "при обновлении хоста создаётся новая переменная" do
    host = Host.create!(host_params("ws-add-#{SecureRandom.hex(3)}"))
    patch host_path(host), params: {
      host: host_params(host.name).merge(
        variables_attributes: { "0" => { name: "env", value: "prod" } }
      )
    }
    assert_response :redirect
    variable = host.reload.variables.find_by(name: "env")
    assert_not_nil variable
    assert_equal "prod", variable.value
  end

  test "пустая строка переменной не создаёт запись (reject_if)" do
    host = Host.create!(host_params("ws-blank-#{SecureRandom.hex(3)}"))
    patch host_path(host), params: {
      host: host_params(host.name).merge(
        variables_attributes: { "0" => { name: "", value: "x" } }
      )
    }
    assert_response :redirect
    assert_equal 0, host.reload.variables.count
  end

  test "все переменные хоста можно удалить через _destroy" do
    host = Host.create!(host_params("ws-del-#{SecureRandom.hex(3)}"))
    v1 = Variable.create!(variableable: host, name: "a", value: "1")
    v2 = Variable.create!(variableable: host, name: "b", value: "2")

    patch host_path(host), params: {
      host: host_params(host.name).merge(
        variables_attributes: {
          "0" => { id: v1.id, name: "a", value: "1", _destroy: "1" },
          "1" => { id: v2.id, name: "b", value: "2", _destroy: "1" }
        }
      )
    }
    assert_response :redirect
    assert_equal 0, host.reload.variables.count
  end

  # Сценарий из UI: добавили пустую строку переменной, не заполнили и удалили.
  # Браузер шлёт её как новую (без id) с _destroy=1 — запись создаваться не должна.
  test "новая строка с _destroy=1 и пустым именем не создаёт запись" do
    host = Host.create!(host_params("ws-addrm-#{SecureRandom.hex(3)}"))
    kept = Variable.create!(variableable: host, name: "keep", value: "1")

    patch host_path(host), params: {
      host: host_params(host.name).merge(
        variables_attributes: {
          "0" => { id: kept.id, name: "keep", value: "1", _destroy: "0" },
          "1" => { name: "", value: "", encrypted: "0", _destroy: "1" }
        }
      )
    }
    assert_response :redirect
    assert_equal ["keep"], host.reload.variables.pluck(:name)
  end

  test "форма редактирования организации без переменных показывает пустой список" do
    get edit_organization_path(@organization)
    assert_response :success
    assert_no_match(/variables_attributes/, @response.body)
  end

  test "организацию можно создать без переменных" do
    name = "org-new-#{SecureRandom.hex(4)}"
    post organizations_path, params: { organization: { name: name } }
    assert_response :redirect
    org = Organization.find_by(name: name)
    assert_not_nil org
    assert_equal 0, org.variables.count
  end

  test "при обновлении организации создаётся новая переменная (префикс organization)" do
    patch organization_path(@organization), params: {
      organization: {
        name: @organization.name,
        variables_attributes: { "0" => { name: "domain", value: "mido-office.local" } }
      }
    }
    assert_response :redirect
    variable = @organization.reload.variables.find_by(name: "domain")
    assert_not_nil variable
    assert_equal "mido-office.local", variable.value
  end

  test "все переменные организации можно удалить через _destroy" do
    v1 = Variable.create!(variableable: @organization, name: "a", value: "1")
    v2 = Variable.create!(variableable: @organization, name: "b", value: "2")

    patch organization_path(@organization), params: {
      organization: {
        name: @organization.name,
        variables_attributes: {
          "0" => { id: v1.id, name: "a", value: "1", _destroy: "1" },
          "1" => { id: v2.id, name: "b", value: "2", _destroy: "1" }
        }
      }
    }
    assert_response :redirect
    assert_equal 0, @organization.reload.variables.count
  end

  # То же для организации (префикс organization).
  test "организация: новая строка с _destroy=1 и пустым именем не создаёт запись" do
    kept = Variable.create!(variableable: @organization, name: "keep", value: "1")

    patch organization_path(@organization), params: {
      organization: {
        name: @organization.name,
        variables_attributes: {
          "0" => { id: kept.id, name: "keep", value: "1", _destroy: "0" },
          "1" => { name: "", value: "", encrypted: "0", _destroy: "1" }
        }
      }
    }
    assert_response :redirect
    assert_equal ["keep"], @organization.reload.variables.pluck(:name)
  end

  test "при удалении организации удаляются её хосты и их переменные" do
    host = Host.create!(host_params("ws-cascade-#{SecureRandom.hex(3)}"))
    Variable.create!(variableable: host, name: "env", value: "prod")

    delete organization_path(@organization)
    assert_response :redirect
    assert_nil Organization.find_by(id: @organization.id)
    assert_nil Host.find_by(id: host.id)
  end

  test "при удалении организации хосты других организаций не затрагиваются" do
    other = Organization.create!(name: "org-other-#{SecureRandom.hex(4)}")
    foreign_host = Host.create!({
      name: "ws-other-#{SecureRandom.hex(3)}",
      ip: "10.0.1.5",
      type: "WorkStation",
      os_type: "Windows",
      role: ["1С"],
      organization_id: other.id
    })

    delete organization_path(@organization)
    assert_response :redirect
    assert_not_nil Host.find_by(id: foreign_host.id)
  end

  test "организация удаляется без ошибки, даже если в системе есть плеи" do
    Play.create!(name: "pl-#{SecureRandom.hex(3)}", os_type: "ubuntu")

    delete organization_path(@organization)
    assert_response :redirect
    assert_nil Organization.find_by(id: @organization.id)
  end
end
