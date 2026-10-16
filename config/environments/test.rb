require "active_support/core_ext/integer/time"

# Тестовое окружение используется только для запуска тестового сьюта.
# Тестовая БД — «черновик»: она стирается и пересоздаётся между прогонами,
# не полагайтесь на данные в ней.

Rails.application.configure do
  # Настройки здесь имеют приоритет над config/application.rb.

  # Кэшируем классы: в тестах перезагрузка кода не нужна.
  config.cache_classes = true

  # Eager load поднимает всё приложение в память: для одиночного локального
  # теста не нужен, но полезен в CI (находит ошибки загрузки до деплоя).
  config.eager_load = ENV["CI"].present?

  # Публичный файловый сервер для тестов с Cache-Control (быстрее).
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Полные отчёты об ошибках, кэширование выключено.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Бросать исключения вместо рендера страниц ошибок.
  config.action_dispatch.show_exceptions = false

  # Защита от CSRF в тестах выключена (тесты не шлют токены).
  config.action_controller.allow_forgery_protection = false

  # Загруженные файлы — во временном каталоге локальной ФС.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Почта не уходит «в реальный мир»: метод :test копит письма в массиве
  # ActionMailer::Base.deliveries (удобно проверять в тестах).
  config.action_mailer.delivery_method = :test

  # Сообщения о депрекациях — в stderr.
  config.active_support.deprecation = :stderr

  # Запрещённые депрекации — с исключением.
  config.active_support.disallowed_deprecation = :raise

  # Список запрещённых сообщений о депрекациях (пусто).
  config.active_support.disallowed_deprecation_warnings = []

  # Ошибка при отсутствии перевода (выключено).
  # config.i18n.raise_on_missing_translations = true

  # Помечать отрендеренное представление именем файла (отладка).
  # config.action_view.annotate_rendered_view_with_filenames = true
end
