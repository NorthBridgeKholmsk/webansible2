require "test_helper"

# Приоритет эффективных переменных: общие -> организация -> хост (+ креды),
# пустые значения никогда не переопределяют непустые нижнего уровня.
class RunVariablesTest < ActiveSupport::TestCase
  def create_host(name, ip:, organization:)
    Host.create!(
      name: name, ip: ip, type: "WorkStation", os_type: "Ubuntu", role: ["web"],
      organization_id: organization.id
    )
  end

  test "приоритет: общие -> организация -> хост" do
    key = "rv_x_#{SecureRandom.hex(3)}"
    CommonVariable.create!(name: key, value: "1")
    org = Organization.create!(name: "org-prio-#{SecureRandom.hex(3)}")
    org.variables.create!(name: key, value: "2")

    h1 = create_host("h-prio-1", ip: "10.7.0.1", organization: org)
    h1.variables.create!(name: key, value: "3")
    h2 = create_host("h-prio-2", ip: "10.7.0.2", organization: org)

    assert_equal "3", RunVariables.for_host(h1)[key] # своя переменная хоста побеждает
    assert_equal "2", RunVariables.for_host(h2)[key] # своей нет — значение организации
  end

  test "пустые креды хоста не затирают org ansible_user/ansible_password" do
    org = Organization.create!(name: "org-creds-#{SecureRandom.hex(3)}")
    org.variables.create!(name: "ansible_user", value: "deploy")
    org.variables.create!(name: "ansible_password", value: "s3cret")

    h1 = create_host("h-creds-1", ip: "10.7.0.3", organization: org) # без login/password

    vars = RunVariables.for_host(h1)
    assert_equal "deploy", vars["ansible_user"]
    assert_equal "s3cret", vars["ansible_password"]
  end

  test "непустые креды хоста переопределяют организацию" do
    org = Organization.create!(name: "org-creds2-#{SecureRandom.hex(3)}")
    org.variables.create!(name: "ansible_user", value: "deploy")
    org.variables.create!(name: "ansible_password", value: "s3cret")

    h1 = Host.create!(
      name: "h-creds-2", ip: "10.7.0.4", type: "WorkStation", os_type: "Ubuntu", role: ["web"],
      login: "root", password: "pw123", organization_id: org.id
    )

    vars = RunVariables.for_host(h1)
    assert_equal "root", vars["ansible_user"]
    assert_equal "pw123", vars["ansible_password"]
  end

  test "зашифрованные значения читаются расшифрованными" do
    org = Organization.create!(name: "org-enc-#{SecureRandom.hex(3)}")
    org.variables.create!(name: "db_pass", value: VariableCipher.encrypt("topsecret"), encrypted: true)

    h1 = create_host("h-enc-1", ip: "10.7.0.5", organization: org)
    assert_equal "topsecret", RunVariables.for_host(h1)["db_pass"]
  end

  test "ansible_host берётся из IP хоста и переопределяет нижние уровни" do
    org = Organization.create!(name: "org-ahost-#{SecureRandom.hex(3)}")
    org.variables.create!(name: "ansible_host", value: "10.99.99.99")

    h1 = create_host("h-ahost-1", ip: "10.7.0.6", organization: org)
    assert_equal "10.7.0.6", RunVariables.for_host(h1)["ansible_host"]
  end

  test "from_form берёт только непустые пары имя/значение" do
    params = {
      variables: {
        "0" => { name: "a", value: "1" },
        "1" => { name: "b", value: "" }, # пустое значение — пропускается
        "2" => { name: "", value: "x" }  # без имени — пропускается
      }
    }
    assert_equal({ "a" => "1" }, RunVariables.from_form(params))
  end

  test "from_form работает с ActionController::Parameters и пустыми переменными" do
    params = ActionController::Parameters.new(
      variables: { "0" => { name: "k", value: "v" } }
    )
    assert_equal({ "k" => "v" }, RunVariables.from_form(params))

    assert_equal({}, RunVariables.from_form(ActionController::Parameters.new(variables: {})))
  end
end
