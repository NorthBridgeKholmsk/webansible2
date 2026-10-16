require_relative "boot"

require "rails/all"

# Подгружаем гемы из Gemfile (включая ограниченные группами
# :test / :development / :production).
Bundler.require(*Rails.groups)

module Webansible2
  class Application < Rails::Application
    # Базовые настройки по умолчанию для версии Rails, при которой
    # создавалось приложение.
    config.load_defaults 7.0

    # Убираем Rack::ETag из стека по умолчанию (Rails 7 добавляет его всегда).
    # Причина: Rack::ETag#digest_body проходит body.each() ПОЛНОСТЬЮ до отдачи
    # ответа, чтобы посчитать дайджест — для стриминговых ответов (ActionController::Live,
    # JSON-lines прогресса в dashboard#zabbix_sync) это означает, что Puma получает все
    # куски только после завершения действия (~1 минута «подвисания» модалки).
    # Для внутреннего админ-дашборда ETag-кэширование страниц не критично.
    config.middleware.delete ::Rack::ETag

    # Общие настройки приложения, движков и railties пишутся здесь;
    # они могут быть переопределены в файлах config/environments
    # (обрабатываются позже).
    #
    # config.time_zone = "Moscow"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
