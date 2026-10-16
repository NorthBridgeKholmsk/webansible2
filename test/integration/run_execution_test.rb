require "test_helper"
require "base64"

# Реальный запуск плейбука (RunLauncher): файлы на диске, отсоединённый
# процесс, опрос вывода через /runs/:id/output. Метод spawn стабится, чтобы
# тесты не зависели от реальных хостов и ansible-playbook.
class RunExecutionTest < ActionDispatch::IntegrationTest
  PLAYBOOK_YAML = <<~YAML
    ---
    - name: Test play
      hosts: all
      vars:
        app_env: staging
      tasks:
        - name: Say hi
          debug:
            msg: "hello from ansible"
  YAML

  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }

    @organization = Organization.create!(name: "org-exec-#{SecureRandom.hex(4)}")
    @playbook = Playbook.create!(name: "pb-exec-#{SecureRandom.hex(3)}", os_type: "ubuntu", content: PLAYBOOK_YAML)

    # Параллельные тестовые воркеры имеют отдельные БД, но общий Rails.root/tmp —
    # изолируем файлы запусков по процессу.
    Run.runs_root = Rails.root.join("tmp", "ansible", "runs-test-#{Process.pid}")
    @original_spawn = RunLauncher.singleton_method(:spawn_command)
  end

  teardown do
    RunLauncher.define_singleton_method(:spawn_command, @original_spawn)
    FileUtils.rm_rf(Run.runs_root)
  end

  def create_host(name, ip:, organization: @organization)
    Host.create!(
      name: name, ip: ip, type: "WorkStation", os_type: "Ubuntu", role: ["web"],
      organization_id: organization.id
    )
  end

  # Стаб RunLauncher.spawn_command: синхронно пишет лог и код возврата,
  # возвращает гарантированно мёртвый PID. Возвращает массив команд для проверок.
  def stub_spawn(exit_code:, log_lines:)
    commands = []
    RunLauncher.define_singleton_method(:spawn_command) do |command, dir:, log_path:|
      commands << command
      File.binwrite(log_path.to_s, log_lines.join("\n") + "\n")
      File.write(File.join(dir.to_s, "exit_code"), exit_code.to_s)
      pid = Process.spawn("true")
      Process.wait2(pid)
      pid
    end
    commands
  end

  def post_run(host_ids:, variables: {})
    post run_path, params: { playbook_id: @playbook.id, host_ids: host_ids, variables: variables }
  end

  test "запуск создаёт файлы и редиректит на страницу запуска" do
    # Креды организации должны сохраниться, если у хоста нет login/password.
    @organization.variables.create!(name: "ansible_user", value: "deploy")
    @organization.variables.create!(name: "ansible_password", value: "s3cret")
    h1 = create_host("web-exec-1", ip: "10.5.0.11")

    commands = stub_spawn(exit_code: 0, log_lines: ["PLAY [all] *****", "ok: [web-exec-1] => changed"])

    post_run(host_ids: [h1.id.to_s], variables: { "0" => { name: "app_env", value: "prod" } })
    assert_response :redirect

    run = Run.last
    refute_nil run
    assert_redirected_to run_show_path(run)
    assert_equal Run::STATUS_RUNNING, run.reload.status

    dir = run.run_dir
    assert_equal @playbook.content, File.read(dir.join("playbook.yml"))

    inventory = YAML.safe_load(File.read(dir.join("inventory.yml")))
    host_vars = inventory["all"]["hosts"][h1.name]
    refute_nil host_vars
    assert_equal "10.5.0.11", host_vars["ansible_host"]
    # Креды организации не затёрты пустыми кредами хоста.
    assert_equal "deploy", host_vars["ansible_user"]
    assert_equal "s3cret", host_vars["ansible_password"]

    vars = YAML.safe_load(File.read(dir.join("vars.yml")))
    assert_equal({ "app_env" => "prod" }, vars)

    # Переменные формы идут через -e (extra-vars — наивысший приоритет в ansible).
    assert_match(/-e @vars\.yml/, commands.last)
    assert_match(/ANSIBLE_CONFIG=/, commands.last)

    follow_redirect!
    assert_response :success
    assert_match(@playbook.name, @response.body)
    assert_match(h1.name, @response.body)
  end

  test "endpoint output отдаёт чанки и доходит до succeeded" do
    h1 = create_host("web-exec-2", ip: "10.5.0.12")
    stub_spawn(exit_code: 0, log_lines: ["hello from ansible"])

    post_run(host_ids: [h1.id.to_s])
    run = Run.last

    offset = 0
    text = +""
    data = nil
    deadline = Time.current + 5
    loop do
      get "/runs/#{run.id}/output", params: { after: offset }
      assert_response :success
      data = JSON.parse(@response.body)
      b64 = data["chunk_b64"].to_s
      unless b64.empty?
        chunk = Base64.strict_decode64(b64)
        text << chunk
        offset += chunk.bytesize
      end
      break if ["succeeded", "failed"].include?(data["status"]) || Time.current > deadline

      sleep 0.1
    end

    assert_equal "succeeded", data["status"]
    assert_equal 0, data["exit_code"]
    assert_includes text, "hello from ansible"
    assert_equal Run::STATUS_SUCCEEDED, run.reload.status
  end

  test "ненулевой код возврата — статус failed" do
    h1 = create_host("web-exec-3", ip: "10.5.0.13")
    stub_spawn(exit_code: 2, log_lines: ["fatal: [web-exec-3] => FAILED"])

    post_run(host_ids: [h1.id.to_s])
    run = Run.last

    get "/runs/#{run.id}/output", params: { after: 0 }
    data = JSON.parse(@response.body)
    assert_equal "failed", data["status"]
    assert_equal 2, data["exit_code"]
    assert_includes Base64.strict_decode64(data["chunk_b64"]), "FAILED"
  end

  test "запуск без переменных формы — в команде нет -e" do
    h1 = create_host("web-exec-4", ip: "10.5.0.14")
    commands = stub_spawn(exit_code: 0, log_lines: ["ok"])

    post_run(host_ids: [h1.id.to_s])
    assert_response :redirect
    refute_match(/-e @vars\.yml/, commands.last)

    # vars.yml создаётся (для аудита), но пустой.
    run = Run.last
    assert_equal "", File.read(run.run_dir.join("vars.yml"))
  end
end
