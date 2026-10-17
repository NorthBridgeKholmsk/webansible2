# Запуск плея на наборе хостов.
#
# Сам процесс запускается отсоединённо от Puma (см. RunLauncher):
# ansible-playbook работает в собственном процессе-группе, вывод идёт на диск
# (tmp/ansible/runs/<id>/log.txt), код возврата — в файл exit_code. Поэтому
# live-вывод через polling переживает рестарты/перезагрузки Puma, а статус
# выводится из состояния на диске (refresh_status!).
class Run < ApplicationRecord
  STATUS_PENDING = "pending"
  STATUS_RUNNING = "running"
  STATUS_SUCCEEDED = "succeeded"
  STATUS_FAILED = "failed"

  STATUSES = [STATUS_PENDING, STATUS_RUNNING, STATUS_SUCCEEDED, STATUS_FAILED].freeze
  TERMINAL_STATUSES = [STATUS_SUCCEEDED, STATUS_FAILED].freeze

  belongs_to :play
  belongs_to :user, optional: true

  serialize :hosts_snapshot, coder: JSON
  serialize :variables, coder: JSON

  validates :status, inclusion: { in: STATUSES }

  class << self
    # Корневой каталог файлов запусков. Переопределяемый (например, на
    # отдельный каталог в каждом воркере параллельных тестов).
    def runs_root
      @runs_root ||= Rails.root.join("tmp", "ansible", "runs")
    end

    attr_writer :runs_root
  end

  def run_dir
    self.class.runs_root.join(id.to_s)
  end

  def log_path
    run_dir.join("log.txt")
  end

  def exit_code_path
    run_dir.join("exit_code")
  end

  def pid_path
    run_dir.join("pid")
  end

  # Новый вывод начиная с байта `from`: [чанк, полный размер файла].
  # Если лога ещё нет (процесс не стартовал) — пустой чанк.
  def read_output(from = 0)
    return ["", 0] unless File.exist?(log_path)

    size = File.size(log_path)
    from = [from.to_i, 0].max
    return ["", size] if from >= size

    [File.binread(log_path, nil, from), size]
  end

  # Статус выводится из маркера exit_code и живости PID:
  #   - есть файл exit_code -> 0 это succeeded, иначе failed;
  #   - процесс жив          -> running;
  #   - мёртв без маркера    -> failed (убит/упал).
  def refresh_status!
    if File.exist?(exit_code_path)
      code = File.read(exit_code_path).strip.to_i
      self.status = code.zero? ? STATUS_SUCCEEDED : STATUS_FAILED
      self.exit_code ||= code
      self.finished_at ||= Time.current
    elsif pid_alive?
      self.status = STATUS_RUNNING if status == STATUS_PENDING
      self.started_at ||= Time.current
    else
      unless TERMINAL_STATUSES.include?(status)
        self.status = STATUS_FAILED
        self.finished_at ||= Time.current
      end
    end
    save! if changed?
  end

  private

  def pid_alive?
    raw = File.exist?(pid_path) ? File.read(pid_path).strip : ""
    return false if raw.empty?

    Process.kill(0, raw.to_i)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    # Процесс существует, но принадлежит другому пользователю — считаем живым.
    true
  end
end
