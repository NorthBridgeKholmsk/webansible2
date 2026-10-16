require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Настройки здесь имеют приоритет над config/application.rb.

  # В development код перезагружается при каждом изменении: ответ медленнее,
  # но не нужно перезапускать веб-сервер после правок кода.
  config.cache_classes = false

  # Не загружать весь код при старте (ленивая загрузка).
  config.eager_load = false

  # Полные отчёты об ошибках для локальных запросов.
  config.consider_all_requests_local = true

  # Заголовок Server-Timing в ответах.
  config.server_timing = true

  # Кэширование по умолчанию выключено; переключается файлом-флагом
  # (rails dev:cache создаёт/удаляет tmp/caching-dev.txt).
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Загруженные файлы — на локальной ФС (варианты в config/storage.yml).
  config.active_storage.service = :local

  # Ошибки отправки почты не критичны в development.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Сообщения о депрекациях — в лог Rails.
  config.active_support.deprecation = :log

  # Запрещённые депрекации — с исключением.
  config.active_support.disallowed_deprecation = :raise

  # Список запрещённых сообщений о депрекациях (пусто).
  config.active_support.disallowed_deprecation_warnings = []

  # Ошибка при загрузке страницы, если есть неприменённые миграции.
  config.active_record.migration_error = :page_load

  # В логах подсвечивать код, инициировавший запрос к БД.
  config.active_record.verbose_query_logs = true

  # Не логировать запросы на ассеты (меньше шума).
  config.assets.quiet = true

  # Ошибка при отсутствии перевода (выключено).
  # config.i18n.raise_on_missing_translations = true

  # Помечать отрендеренное представление именем файла (отладка).
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Разкомментировать, чтобы разрешить Action Cable с любого origin.
  # config.action_cable.disable_request_forgery_protection = true
end
