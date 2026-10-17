class DashboardController < ApplicationController
  # Стриминг ответов (JSON-lines прогресса синхронизации) — см. zabbix_sync.
  include ActionController::Live
  def index
    @organization_count = Organization.count
    @host_count = Host.count
    @play_count = Play.count
    @playbook_count = Playbook.count
    @file_count = FileEntry.count
    @variables_count = Variable.count
    content_for(:page_title) { "Главная" }
  end

  # Синхронизация хостов и организаций из Zabbix.
  # Отдаёт поток JSON-lines: строка статуса, затем каждый шаг — {"processed":N,"total":M},
  # финальная строка — сводка с "done".
  # ActionController::Live: действие выполняется в отдельном потоке, каждая запись
  # response.stream.write сразу уходит клиенту (настоящий стриминг). Обычный
  # response.write здесь не работает: он копит всё в памяти и отдаёт одним куском
  # только после завершения действия (~1 минута «подвисания» модалки).
  # Логирование процесса: Rails.logger (log/development.log в dev).
  def zabbix_sync
    # require_admin! здесь не подходит: он делает redirect_to без остановки выполнения,
    # и для не-админа синхронизация продолжилась бы поверх редиректа.
    return redirect_to root_path, alert: "У вас нет прав" unless current_user&.admin?

    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    response.headers["Cache-Control"] = "no-cache"
    # Если пользователь закроет модалку, не прерываем синхронизацию:
    # записи в «мёртвый» поток молча отбрасываются.
    # (В тестах stream — обычный Buffer без этого метода, поэтому guard.)
    response.stream.ignore_disconnect = true if response.stream.respond_to?(:ignore_disconnect=)

    # Серверный guard «одна синхронизация одновременно» (Puma однопроцессный).
    # Второй запрос (другая вкладка / двойной клик) не стартует новый fetch,
    # а сообщает, что синхронизация уже идёт. Отдельная ветка до begin/ensure:
    # при отказе guard мы НЕ должны звать finish_sync! — он снял бы флаг
    # чужой идущей синхронизации.
    unless Zabbix::Syncer.try_begin_sync!
      Rails.logger.info("[ZabbixSync] rejected, already running user=#{current_user&.login}")
      stream_line(type: "status", message: "Синхронизация уже выполняется")
      stream_line({ done: true, total: 0, message: "Синхронизация уже выполняется" })
      response.stream.close
      return
    end

    started_at = Time.current
    Rails.logger.info("[ZabbixSync] start user=#{current_user&.login} url=#{Zabbix::Settings.url}")

    result = nil
    begin
      stream_line(type: "status", message: "Запрашиваю данные у Zabbix…")
      syncer = Zabbix::Syncer.new(result_callback: ->(progress) { stream_line(progress) })
      result = syncer.run
    rescue => e
      Rails.logger.error("[ZabbixSync] error: #{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}")
      result = Zabbix::Syncer::Result.new(
        total: 0, created: 0, updated: 0, skipped: 0,
        errors: [{ name: nil, message: e.message }]
      )
    ensure
      # Guard снимаем всегда — даже при ошибке синхронизации.
      Zabbix::Syncer.finish_sync!
      begin
        stream_line(result ? result.to_summary : { done: true, total: 0 })
      rescue => e
        Rails.logger.warn("[ZabbixSync] не удалось отправить сводку: #{e.class}: #{e.message}")
      end
      Rails.logger.info(
        "[ZabbixSync] done in #{(Time.current - started_at).round(1)}s " \
        "total=#{result&.total || 0} created=#{result&.created || 0} updated=#{result&.updated || 0} " \
        "skipped=#{result&.skipped || 0} errors=#{Array(result&.errors).map { |er| er.is_a?(Hash) ? (er["message"] || er[:message]) : nil }.first(5)}"
      )
      response.stream.close
    end
  end

  # Отмена идущей синхронизации (кнопка «Отменить» в модалке).
  # Ставит серверный флаг; Syncer проверяет его в начале каждой итерации
  # и останавливается, итог приходит клиенту обычной done-строкой по стриму.
  def zabbix_sync_cancel
    return redirect_to root_path, alert: "У вас нет прав" unless current_user&.admin?

    Zabbix::Syncer.request_cancel!
    Rails.logger.info("[ZabbixSync] cancel requested user=#{current_user&.login}")
    render json: { cancelled: true }
  end

  private

  def stream_line(hash)
    response.stream.write(JSON.generate(hash) + "\n")
  rescue ActionController::Live::ClientDisconnected => e
    Rails.logger.info("[ZabbixSync] клиент отключился: #{e.class}")
  end
end
