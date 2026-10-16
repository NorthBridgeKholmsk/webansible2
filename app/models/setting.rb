# Глобальные настройки приложения в формате key/value (таблица settings).
#
# Здесь хранятся и параметры из «Настроек» (Settings::AppConfig),
# и подключение к Zabbix (Zabbix::Settings) — API-ключ зашифрован.
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true
end
