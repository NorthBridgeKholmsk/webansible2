# Подготовка файлов запуска и запуск ansible-playbook отсоединённым процессом.
#
# Процесс работает через /bin/sh -c в собственной группе процессов
# (pgroup: true), вывод идёт в log.txt, код возврата — в файл exit_code;
# PID сохраняется в pid-файл (задел под будущую «Отмену»). Всё это позволяет
# запуску переживать рестарты/перезагрузки Puma, а статусу выводится из
# состояния на диске (Run#refresh_status!).
class RunLauncher
  ANSIBLE_PLAYBOOK_BIN = "/usr/bin/ansible-playbook"

  class LaunchError < StandardError; end

  # Метод spawn вынесен отдельно — для стаба в тестах.
  def self.spawn_command(command, dir:, log_path:)
    Process.spawn(
      "/bin/sh", "-c", command,
      chdir: dir.to_s,
      out: log_path.to_s,
      err: [:child, :out],
      pgroup: true
    )
  end

  # hosts — массив пар [имя_хоста, эффективные_переменные] (RunVariables.for_host).
  def self.launch(run, playbook:, hosts:, form_vars:)
    dir = run.run_dir
    FileUtils.mkdir_p(dir)
    File.chmod(0o700, dir)

    write_protected(dir.join("playbook.yml"), playbook.content.to_s)
    write_protected(dir.join("inventory.yml"), build_inventory(hosts).to_yaml)
    # Переменные формы пишутся всегда (для аудита), но -e добавляется в команду
    # только при непустых — пустой extra-vars файл ansible обрабатывает криво.
    write_protected(dir.join("vars.yml"), form_vars.empty? ? "" : form_vars.to_yaml)
    # UserKnownHostsFile=/dev/null: ssh не читает known_hosts вообще, поэтому
    # изменённый host key пересобранного хоста (REMOTE HOST IDENTIFICATION HAS
    # CHANGED) не блокирует запуск — StrictHostKeyChecking=no его не спасает.
    # ssh_args живёт в секции [ssh_connection] ([defaults] его игнорирует);
    # ControlMaster/ControlPersist сохраняем, т.к. значение заменяет дефолты.
    write_protected(
      dir.join("ansible.cfg"),
      "[defaults]\n" \
      "host_key_checking = False\n" \
      "\n" \
      "[ssh_connection]\n" \
      "ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null\n"
    )

    cfg_path = dir.join("ansible.cfg")
    extra_vars = form_vars.empty? ? "" : " -e @vars.yml"
    command = "ANSIBLE_CONFIG=#{cfg_path} #{ANSIBLE_PLAYBOOK_BIN} " \
              "-i inventory.yml playbook.yml#{extra_vars}; echo $? > exit_code"

    pid = spawn_command(command, dir: dir, log_path: run.log_path)
    write_protected(run.pid_path, "#{pid}\n")
    run.update_columns(status: Run::STATUS_RUNNING, started_at: Time.current)
    pid
  rescue StandardError => e
    raise LaunchError, "Не удалось запустить ansible-playbook: #{e.message}"
  end

  # Инвентарь в YAML-форме: all.hosts.<имя> = эффективные переменные хоста.
  def self.build_inventory(hosts)
    hosts_map = {}
    Array(hosts).each do |name, vars|
      hosts_map[name.to_s] = (vars || {}).transform_values { |v| v.nil? ? nil : v.to_s }
    end
    { "all" => { "hosts" => hosts_map } }
  end

  class << self
    private

    # Файлы запуска содержат секреты (креды, переменные) — только владелец.
    def write_protected(path, content)
      File.binwrite(path, content)
      File.chmod(0o600, path)
    end
  end
end
