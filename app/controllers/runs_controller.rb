class RunsController < ApplicationController
  # GET /run — страница запуска плея.
  def new
    @plays = Play.order(:name)
    @all_hosts = Host.includes(:organization).order(:name)

    # Глубокая ссылка ?play_id=N: предзаполняем переменные из YAML плея,
    # чтобы страница выглядела так же, как после выбора через JS.
    if params[:play_id].present?
      @play = Play.find_by(id: params[:play_id])
      result = PlayVariableParser.parse(@play&.content)
      @parsed_variables = result.ok? ? result.variables : []
      @variables_error = result.error unless result.ok?
    end

    content_for(:page_title) { "Запуск плея" }
  end

  # GET /run/variables?play_id=N — JSON-список переменных плея (блоки vars:
  # в начале файла). Вызывается fetch'ем из JS при смене выбранного плея,
  # без перезагрузки страницы.
  def variables
    play = Play.find_by(id: params[:play_id])
    if play.nil?
      render json: { error: "Плей не найден" }, status: :not_found and return
    end

    result = PlayVariableParser.parse(play.content)
    if result.ok?
      render json: result.variables.map { |name, value| { name: name, value: value } }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # POST /run — запуск плея на выбранных хостах: создаёт Run со снапшотом,
  # пишет файлы (плей/инвентарь/переменные) и стартует ansible-playbook
  # отсоединённым процессом. Страница запуска — /runs/:id с live-выводом.
  def create
    @plays = Play.order(:name)
    @all_hosts = Host.includes(:organization).order(:name)
    @errors = nil

    play_id = params[:play_id].to_s.strip
    # Чекбоксы списка хостов шлют массив host_ids[]; для совместимости
    # принимаем и старую запятой-строку.
    raw_host_ids = params[:host_ids]
    host_ids = (raw_host_ids.is_a?(Array) ? raw_host_ids : raw_host_ids.to_s.split(","))
             .map(&:to_s).reject { |v| v.strip.empty? }

    @play = Play.find_by(id: play_id) if play_id.present?
    hosts = Host.where(id: host_ids).includes(:organization).to_a

    if @play.nil? || hosts.empty?
      @errors = "Выберите плей и хотя бы один хост."
      # Сохраняем предзаполнение переменных при повторном рендере формы.
      if @play
        result = PlayVariableParser.parse(@play.content)
        @parsed_variables = result.ok? ? result.variables : []
      end
      render :new, status: :unprocessable_entity and return
    end

    form_vars = RunVariables.from_form(params)
    effective_hosts = hosts.map { |h| [h.name, RunVariables.for_host(h)] }

    run = Run.create!(
      play: @play,
      user: current_user,
      status: Run::STATUS_PENDING,
      hosts_snapshot: hosts.map { |h| { "name" => h.name, "ip" => h.ip } },
      variables: { "form" => form_vars, "hosts" => effective_hosts.to_h }
    )

    begin
      RunLauncher.launch(run, play: @play, hosts: effective_hosts, form_vars: form_vars)
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