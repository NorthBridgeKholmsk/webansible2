class RunsController < ApplicationController
  # GET /run — страница запуска плейбука.
  def new
    @playbooks = Playbook.order(:name)
    @all_hosts = Host.includes(:organization).order(:name)

    # Глубокая ссылка ?playbook_id=N: предзаполняем переменные из YAML плейбука,
    # чтобы страница выглядела так же, как после выбора через JS.
    if params[:playbook_id].present?
      @playbook = Playbook.find_by(id: params[:playbook_id])
      result = PlaybookVariableParser.parse(@playbook&.content)
      @parsed_variables = result.ok? ? result.variables : []
      @variables_error = result.error unless result.ok?
    end

    content_for(:page_title) { "Запуск плейбука" }
  end

  # GET /run/variables?playbook_id=N — JSON-список play-уровневых переменных
  # плейбука (блок vars: в начале файла). Вызывается fetch'ем из JS при смене
  # выбранного плейбука, без перезагрузки страницы.
  def variables
    playbook = Playbook.find_by(id: params[:playbook_id])
    if playbook.nil?
      render json: { error: "Плейбук не найден" }, status: :not_found and return
    end

    result = PlaybookVariableParser.parse(playbook.content)
    if result.ok?
      render json: result.variables.map { |name, value| { name: name, value: value } }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # POST /run — запуск плейбука на выбранных хостах: создаёт Run со снапшотом,
  # пишет файлы (плейбук/инвентарь/переменные) и стартует ansible-playbook
  # отсоединённым процессом. Страница запуска — /runs/:id с live-выводом.
  def create
    @playbooks = Playbook.order(:name)
    @all_hosts = Host.includes(:organization).order(:name)
    @errors = nil

    playbook_id = params[:playbook_id].to_s.strip
    # Чекбоксы списка хостов шлют массив host_ids[]; для совместимости
    # принимаем и старую запятой-строку.
    raw_host_ids = params[:host_ids]
    host_ids = (raw_host_ids.is_a?(Array) ? raw_host_ids : raw_host_ids.to_s.split(","))
             .map(&:to_s).reject { |v| v.strip.empty? }

    @playbook = Playbook.find_by(id: playbook_id) if playbook_id.present?
    hosts = Host.where(id: host_ids).includes(:organization).to_a

    if @playbook.nil? || hosts.empty?
      @errors = "Выберите плейбук и хотя бы один хост."
      # Сохраняем предзаполнение переменных при повторном рендере формы.
      if @playbook
        result = PlaybookVariableParser.parse(@playbook.content)
        @parsed_variables = result.ok? ? result.variables : []
      end
      render :new, status: :unprocessable_entity and return
    end

    form_vars = RunVariables.from_form(params)
    effective_hosts = hosts.map { |h| [h.name, RunVariables.for_host(h)] }

    run = Run.create!(
      playbook: @playbook,
      user: current_user,
      status: Run::STATUS_PENDING,
      hosts_snapshot: hosts.map { |h| { "name" => h.name, "ip" => h.ip } },
      variables: { "form" => form_vars, "hosts" => effective_hosts.to_h }
    )

    begin
      RunLauncher.launch(run, playbook: @playbook, hosts: effective_hosts, form_vars: form_vars)
    rescue StandardError => e
      run.update_columns(status: Run::STATUS_FAILED, finished_at: Time.current)
      Rails.logger.error("Run ##{run.id} launch failed: #{e.message}")
      @errors = "Не удалось запустить ansible-playbook: #{e.message}"
      render :new, status: :unprocessable_entity and return
    end

    redirect_to run_show_path(run)
  end

  # GET /runs/:id — страница запуска с live-выводом (JS опрашивает output).
  def show
    @run = Run.find(params[:id])
    @run.refresh_status!
    content_for(:page_title) { "Запуск ##{@run.id}" }
  end

  # GET /runs/:id/output?after=N — новый кусок вывода начиная с байта N.
  # Чанк кодируется base64, чтобы мультибайтный UTF-8 не ломался на границе.
  def output
    run = Run.find(params[:id])
    run.refresh_status!
    chunk, size = run.read_output(params.fetch(:after, 0).to_i)
    render json: {
      status: run.status,
      exit_code: run.exit_code,
      size: size,
      chunk_b64: Base64.strict_encode64(chunk)
    }
  end

  helper do
    RUN_STATUS_LABELS = {
      Run::STATUS_PENDING => "Ожидает",
      Run::STATUS_RUNNING => "Выполняется",
      Run::STATUS_SUCCEEDED => "Завершён успешно",
      Run::STATUS_FAILED => "Ошибка"
    }.freeze

    def run_status_label(status)
      RUN_STATUS_LABELS.fetch(status, status.to_s)
    end

    def run_status_badge_class(status)
      case status
      when Run::STATUS_SUCCEEDED then "bg-success"
      when Run::STATUS_FAILED    then "bg-danger"
      when Run::STATUS_RUNNING   then "bg-primary"
      else "bg-secondary"
      end
    end

    def format_run_time(time)
      time ? time.strftime("%d.%m.%Y %H:%M:%S") : "—"
    end

    # Значения с «секретными» именами не показываем в UI.
    def secret_like?(name)
      !!(name.to_s =~ /passw|secret|token/i)
    end
  end
end