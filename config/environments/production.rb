require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Настройки здесь имеют приоритет над config/application.rb.

  # Код не перезагружается между запросами (кэшируем классы).
  config.cache_classes = true

  # Eager load при старте: весь код загружается в память — быстрее и для
  # потоковых веб-серверов, и для режимов с copy-on-write. Rake-задачи этот
  # параметр игнорируют.
  config.eager_load = true

  # Полные отчёты об ошибках выключены, кэширование включено.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Требовать доступности master key (ENV["RAILS_MASTER_KEY"] или
  # config/master.key) — им расшифровываются credentials и другие зашифрованные файлы.
  # config.require_master_key = true

  # По умолчанию не раздавать статику из /public (этим обычно занимается
  # Apache/NGINX); включается переменной RAILS_SERVE_STATIC_FILES.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Сжатие CSS препроцессором (выключено).
  # config.assets.css_compressor = :sass

  # Ассеты собирает Sprockets-пайплайн: приложение работает на Puma без nginx.
  config.assets.compile = true

  # Раздача статики из /public, если включена (см. выше).
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Заголовок для передачи файлов через веб-сервер (выключено).
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Загруженные файлы — на локальной ФС (варианты в config/storage.yml).
  config.active_storage.service = :local

  # Гнездо Action Cable вне основного процесса/домена (выключено).
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Принудительный SSL + HSTS + secure-cookie для всех запросов (выключено).
  # config.force_ssl = true

  # Уровень лога info: достаточно информации о работе системы, но без
  # избытка данных (защита от случайной утечки PII).
  config.log_level = :info

  # Префикс для всех строк лога — теги ниже.
  config.log_tags = [ :request_id ]

  # Другое хранилище кэша в production (выключено).
  # config.cache_store = :mem_cache_store

  # Реальный бэкенд очередей для Active Job (выключено).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "webansible2_production"

  config.action_mailer.perform_caching = false

  # Игнорировать неверные адреса почты и не падать на ошибках доставки;
  # для строгости поставить true и настроить почтовый сервер.
  # config.action_mailer.raise_delivery_errors = false

  # Откат локалей I18n: если перевод для локали не найден, используется
  # I18n.default_locale.
  config.i18n.fallbacks = true

  # Сообщения о депрекациях в лог не пишем.
  config.active_support.report_deprecations = false

  # Стандартный форматтер лога (PID и метка времени не подавляются).
  config.log_formatter = ::Logger::Formatter.new

  # Другой логгер для распределённых конфигураций (выключено).
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Не выгружать схему БД после миграций.
  config.active_record.dump_schema_after_migration = false
end
