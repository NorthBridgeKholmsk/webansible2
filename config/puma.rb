# Каждый запрос обслуживается потоком из внутреннего пула Puma.
# `threads` принимает два числа: минимум и максимум. Библиотеки с собственными
# пулами потоков должны настраиваться под максимальное значение Puma.
# По умолчанию 5/5 — совпадает с размером пула Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Таймаут ожидания «зависшего» воркера в development-окружении.
#
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Порт для приёма запросов (по умолчанию 3000; переопределяется ENV["PORT"]).
# `port` внутри вызывает `bind tcp://0.0.0.0:<port>` — явный `bind` добавлять
# нельзя: появился бы второй идентичный listener и EADDRINUSE при старте.
port ENV.fetch("PORT") { 3000 }

# Хост по умолчанию 0.0.0.0 (все интерфейсы) — именно поэтому приложение
# доступно извне без дополнительной настройки.

# Окружение Rails, в котором работает Puma (по умолчанию development).
environment ENV.fetch("RAILS_ENV") { "development" }

# PID-файл сервера (используется systemd и bin/rails stop).
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Число воркеров в clustered-режиме (форкнутые процессы веб-сервера).
# Совместная конкурентность = threads * workers. На JRuby/Windows воркеры не
# работают — приложение работает в однопроцессном режиме с пулом потоков.
#
# workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# preload_app! — загружать код до форка воркеров (экономия памяти за счёт
# Copy-On-Write); используется вместе с workers.
#
# preload_app!

# Разрешает перезапуск Puma командой `bin/rails restart`.
plugin :tmp_restart
