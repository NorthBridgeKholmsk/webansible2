require "test_helper"

# Конфиденциальные переменные в формах и на страницах:
# - зашифрованное значение не рендерится ни в одном HTML (show/edit/runs);
# - show-страницы показывают статическую маску;
# - сохранение формы с пустым значением не стирает секрет;
# - снятие флага конвертирует переменную в обычную.
class VariablesSecretsTest < ActionDispatch::IntegrationTest
  SECRET = "SuperSecret123!"

  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    @organization = Organization.create!(name: "secrets-org-#{SecureRandom.hex(4)}")
    @host = Host.create!(host_params("secrets-host-#{SecureRandom.hex(3)}"))
    @plain_var = Variable.create!(variableable: @host, name: "env", value: "production")
    @secret_var = Variable.create!(variableable: @host, name: "db_password", value: SECRET, encrypted: true)
  end

  def host_params(name)
    {
      name: name,
      ip: "10.8.8.#{rand(2..254)}",
      type: "WorkStation",
      os_type: "Windows",
      role: ["web"],
      organization_id: @organization.id
    }
  end

  test "show-страница маскирует зашифрованную переменную и показывает обычную" do
    get host_path(@host)
    assert_response :success
    assert_includes response.body, "production"
    refute_includes response.body, SECRET
    assert_includes response.body, "••••••"
  end

  test "форма редактирования не рендерит секрет и содержит чекбокс типа" do
    get edit_host_path(@host)
    assert_response :success
    refute_includes response.body, SECRET
    assert_includes response.body, 'value="production"'
    assert_select "input[type=checkbox][name$='[encrypted]']", count: 2
    # Зашифрованная строка — password-поле без предзаполнения.
    assert_select "input[type=password][name$='[value]']"
  end

  test "сохранение формы с пустым значением не стирает секрет" do
    patch host_path(@host), params: {
      host: host_params(@host.name).merge(
        variables_attributes: {
          "0" => { id: @plain_var.id, name: "env", value: "staging", encrypted: "0" },
          "1" => { id: @secret_var.id, name: "db_password", value: "", encrypted: "1" }
        }
      )
    }
    assert_response :redirect
    host = @host.reload
    assert_equal "staging", host.variables.find_by(name: "env").value
    secret = host.variables.find_by(name: "db_password")
    assert_equal SECRET, secret.value
    assert VariableCipher.encrypted?(secret.read_attribute(:value))
  end

  test "снятие флага конвертирует зашифрованную переменную в обычную" do
    patch host_path(@host), params: {
      host: host_params(@host.name).merge(
        variables_attributes: {
          "0" => { id: @plain_var.id, name: "env", value: "production", encrypted: "0" },
          "1" => { id: @secret_var.id, name: "db_password", value: "", encrypted: "0" }
        }
      )
    }
    assert_response :redirect
    secret = @host.reload.variables.find_by(name: "db_password")
    refute VariableCipher.encrypted?(secret.read_attribute(:value))
    assert_equal SECRET, secret.value
  end

  test "оба типа можно создать через форму" do
    name = "secrets-new-#{SecureRandom.hex(3)}"
    post hosts_path, params: {
      host: host_params(name).merge(
        variables_attributes: {
          "0" => { name: "plain_var", value: "visible" },
          "1" => { name: "secret_var", value: "NewPass456!", encrypted: "1" }
        }
      )
    }
    assert_response :redirect
    host = Host.find_by(name: name)
    refute_nil host
    secret = host.variables.find_by(name: "secret_var")
    assert VariableCipher.encrypted?(secret.read_attribute(:value))
    assert_equal "NewPass456!", secret.value

    get host_path(host)
    refute_includes response.body, "NewPass456!"
  end

  test "show-страница организации маскирует зашифрованные переменные" do
    Variable.create!(variableable: @organization, name: "org_secret", value: "OrgSecret789!", encrypted: true)

    get organization_path(@organization)
    assert_response :success
    refute_includes response.body, "OrgSecret789!"
    assert_includes response.body, "••••••"
  end

  test "страница общих переменных не рендерит секрет; round-trip сохраняет его" do
    cv = CommonVariable.create!(name: "global_secret_#{SecureRandom.hex(3)}", value: "C0mm0nPass!", encrypted: true)

    get common_variables_path
    assert_response :success
    refute_includes response.body, "C0mm0nPass!"
    assert_select "input[type=checkbox][name='items[][encrypted]']"

    patch common_variables_path, params: { items: [ { id: cv.id.to_s, name: cv.name, value: "", encrypted: "1" } ] }
    assert_response :redirect
    cv.reload
    assert_equal "C0mm0nPass!", cv.value
    assert VariableCipher.encrypted?(cv.read_attribute(:value))
  end

  test "runs/new не рендерит секрет зашифрованной переменной плея" do
    pb = Play.create!(name: "pl-secrets-#{SecureRandom.hex(3)}", os_type: "ubuntu")
    pb.variables.create!(name: "pb_secret", value: "PBsecret!", encrypted: true)

    get new_run_path(play_id: pb.id)
    assert_response :success
    refute_includes response.body, "PBsecret!"
  end
end
