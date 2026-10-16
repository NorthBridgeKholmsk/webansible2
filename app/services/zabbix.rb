# Явный файл-неймспейс для Zeitwerk.
#
# Директория app/services/zabbix/ содержит Client / Settings / Syncer, но без
# этого файла неймспейс Zabbix был бы "implicit" (скрытым). В development
# (eager_load=false, lazy-load) implicit-неймспейсы иногда не резolvesятся по
# порядку загрузки и дают:
#   NameError: uninitialized constant ...::Zabbix
# Явный файл гарантирует, что Zeitwerk зарегистрирует autoload для Zabbix в любом
# режиме (dev lazy + prod/test eager) и корректно переживёт code-reload.
module Zabbix; end
