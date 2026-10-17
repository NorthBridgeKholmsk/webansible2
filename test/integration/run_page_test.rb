require "test_helper"

# Страница «Запуск плея» (runs#new):
# - выбор плея, динамические переменные из блока vars: YAML;
# - фильтр хостов и список с чекбоксами;
# - запуск (spawn стабится) с выбранными хостами и переменными.
class RunPageTest < ActionDispatch::IntegrationTest
  PLAY_YAML = <<~YAML
    ---
    - name: Deploy and configure Zabbix Agent
      hosts: all
      become: yes
      vars:
        zabbix_agent_hostname: "{{ inventory_hostname }}"
        zabbix_agent_package: "zabbix-agent"
      tasks:
        - name: Task-level var must be ignored
          vars:
            task_level_var: "drop-me"
          command: echo ok
  YAML

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
    @play = Play.create!(name: "pl-run-#{SecureRandom.hex(3)}", os_type: "ubuntu", content: PLAY_YAML)

    # Не запускаем реальный ansible в тестах: изолируем файлы запусков по
    # процессу и запоминаем оригинальный метод spawn для восстановления.
    Run.runs_root = Rails.root.join("tmp", "ansible", "runs-test-#{Process.pid}")
    @original_spawn = RunLauncher.singleton_method(:spawn_command)
  end

  teardown do
    RunLauncher.define_singleton_method(:spawn_command, @original_spawn)
    FileUtils.rm_rf(Run.runs_root)
  end

  def host_params(name, ip:, type: "WorkStation", os_type: "Windows", role: ["1С"])
    {
      name: name,
      ip: ip,
      type: type,
      os_type: os_type,
      role: role,
      organization_id: @organization.id
    }
  end

  test "страница запуска содержит плей, фильтр хостов и таблицу с чекбоксами" do
    h1 = Host.create!(host_params("ws-run-1", ip: "10.1.0.1"))
    org2 = Organization.create!(name: "org2-#{SecureRandom.hex(4)}")
    h2 = Host.create!(host_params("db-run-2", ip: "10.1.0.2", type: "Server", os_type: "Ubuntu", role: ["db"])
                        .merge(organization_id: org2.id))

    get new_run_path
    assert_response :success

    # Плей и кнопки.
    assert_match(%(id="run-play-select"), @response.body)
    assert_match(@play.name, @response.body)
    assert_match("Запуск плея", @response.body)
    assert_match(/>Отмена</, @response.body)

    # Поля фильтра: единый поиск по имени/IP + организация/тип/роль/ОС.
    %w[run-filter-q run-filter-org run-filter-type run-filter-role run-filter-os].each do |id|
      assert_match(%(id="#{id}"), @response.body)
    end

    # Опции организаций — только те, у которых есть хосты.
    org_select = @response.body[/<select[^>]*id="run-filter-org"[^>]*>.*?<\/select>/m]
    refute_nil org_select, "селект организации не найден"
    assert_match(@organization.name, org_select)
    assert_match(org2.name, org_select)

    # Кнопки фильтра: применяются строго по клику и не должны слать форму запуска.
    assert_match(/<button type="button" id="run-filter-apply"/, @response.body)
    assert_match(/<button type="button" id="run-filter-reset"/, @response.body)

    # Хосты — таблица с чекбоксами и data-атрибутами для клиентской фильтрации.
    assert_match(/<table class="table table-hover/, @response.body)
    assert_equal 2, @response.body.scan(%(name="host_ids\[\]")).size
    assert_match(/id="run-host-#{h1.id}"/, @response.body)
    assert_match(/value="#{h1.id}"/, @response.body)

    row = @response.body[/host-run-row[^>]*data-name="#{Regexp.escape(h2.name)}"[^>]*>/]
    refute_nil row, "строка хоста с data-атрибутами не найдена"
    assert_match(%(data-ip="10.1.0.2"), row)
    assert_match(%(data-type="Server"), row)
    assert_match(%(data-role="db"), row)
    assert_match(%(data-os="Ubuntu"), row)
    assert_match(%(data-org="#{org2.name}"), row)

    # «Выбрать все видимые» — настоящий чекбокс, а не напечатанный хэш.
    assert_match(/<input type="checkbox" id="run-select-all"/, @response.body)
    assert_no_match("form-check-input me-2\"}", @response.body)

    # Кнопка добавления переменной и контейнер переменных.
    assert_match(%(id="run-variables-container"), @response.body)
    assert_match(%(id="add-variable"), @response.body)
  end

  test "глубокая ссылка ?play_id предзаполняет переменные из YAML" do
    get new_run_path, params: { play_id: @play.id }
    assert_response :success

    rows = @response.body.scan(/name="variables\[\d+\]\[name\]"/).size
    assert_equal 2, rows # только play-уровневые vars, task-level не в счёт
    assert_match(%(value="zabbix-agent"), @response.body)
    assert_no_match("task_level_var", @response.body)
  end

  test "endpoint /run/variables отдаёт JSON переменных плея" do
    get run_variables_path, params: { play_id: @play.id }
    assert_response :success
    data = JSON.parse(@response.body)
    assert_equal [
      { "name" => "zabbix_agent_hostname", "value" => "{{ inventory_hostname }}" },
      { "name" => "zabbix_agent_package", "value" => "zabbix-agent" }
    ], data
  end

  test "endpoint /run/variables: неизвестный плей — 404, битый YAML — 422" do
    get run_variables_path, params: { play_id: 999_999 }
    assert_response :not_found

    broken = Play.create!(name: "pl-broken-#{SecureRandom.hex(3)}", os_type: "ubuntu", content: "---\n- name: [unclosed\n")
    get run_variables_path, params: { play_id: broken.id }
    assert_response :unprocessable_entity
    assert_match(/Ошибка разбора YAML/, JSON.parse(@response.body)["error"])
  end

  test "запуск с выбранными хостами и переменными — редирект на страницу запуска" do
    h1 = Host.create!(host_params("ws-run-a", ip: "10.2.0.1"))
    h2 = Host.create!(host_params("ws-run-b", ip: "10.2.0.2"))

    # Стаб spawn: синхронно пишет лог и код возврата, реальный ansible не нужен.
    RunLauncher.define_singleton_method(:spawn_command) do |_command, dir:, log_path:|
      File.binwrite(log_path.to_s, "stub output\n")
      File.write(File.join(dir.to_s, "exit_code"), "0")
      pid = Process.spawn("true")
      Process.wait2(pid)
      pid
    end

    post run_path, params: {
      play_id: @play.id,
      host_ids: [h1.id.to_s, h2.id.to_s],
      variables: {
        "0" => { name: "zabbix_agent_package", value: "zabbix-agent-6.0" },
        "1" => { name: "extra_var", value: "custom" }
      }
    }
    assert_response :redirect

    run = Run.last
    refute_nil run
    assert_redirected_to run_show_path(run)
    follow_redirect!
    assert_response :success
    assert_match(@play.name, @response.body)
    assert_match(h1.name, @response.body)
    assert_match(h2.name, @response.body)
  end

  test "запуск без хостов — ошибка и повторный рендер с предзаполненными переменными" do
    post run_path, params: { play_id: @play.id, host_ids: [] }
    assert_response :unprocessable_entity
    assert_match("Выберите плей и хотя бы один хост.", @response.body)

    # Переменные из YAML сохранены при повторном рендере.
    rows = @response.body.scan(/name="variables\[\d+\]\[name\]"/).size
    assert_equal 2, rows
  end
end
