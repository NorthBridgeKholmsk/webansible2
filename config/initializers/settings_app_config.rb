# Загружает Settings::AppConfig обычным require'ом из lib/.
#
# Файл намеренно вынесен из app/ (см. комментарий в самом файле): директории
# app/* автоматически становятся корнями Zeitwerk с топ-урневым маппингом, и
# `app/settings/app_config.rb` конфликтовал с константой Settings::AppConfig.
# require из lib/ не зависит от Zeitwerk и переживает code-reload в dev.
require Rails.root.join("lib", "settings", "app_config")
