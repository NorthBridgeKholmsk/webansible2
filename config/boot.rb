# Указываем Bundler на Gemfile приложения (если не задано окружением).
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Подключаем гемы из Gemfile.
require "bundler/setup"

unless ENV["NO_BOOTS"]
  # Bootsnap кэширует дорогие операции (разбор кода, загрузка) — ускоряет старт.
  require "bootsnap/setup"
end
