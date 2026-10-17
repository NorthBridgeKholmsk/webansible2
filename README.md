# WebAnsible 2 — v0.1

Веб-интерфейс для запуска Ansible-плеев из браузера: управление
организациями и хостами, переменными (в том числе зашифрованными),
плеями; запуск задач с живым выводом.

## Возможности

- Организации и хосты — вручную или синхронизацией из Zabbix;
- Общие переменные + переменные организаций; чувствительные значения
  хранятся в зашифрованном виде (AES-256-GCM);
- Плеи и файлы хранятся в базе данных — раскладывать их по диску не нужно;
- Запуски с живым выводом, статусами и логами;
- Интеграция Zabbix: синхронизация хостов с прогрессом прямо в UI;
- Роли `admin` / `editor`, темы light/dark.

Стек: Ruby 3.0 · Rails 7.0 · Puma · SQLite3 · importmap + Turbo/Stimulus.

## Быстрый старт

Полная инструкция — [docs/INSTALL.md](docs/INSTALL.md) (systemd, Ansible,
become-плагин для sudo-rs).

```bash
git clone https://github.com/NorthBridgeKholmsk/webansible2.git /opt/webansible2
cd /opt/webansible2
bundle install
bin/rails db:prepare   # создаёт БД и применяет миграции (SQLite)
bin/rails db:seed      # создаёт пользователя admin/admin — сразу смените пароль!
# systemd-юнит и запуск — см. docs/INSTALL.md, раздел 3
```

## Структура проекта

- `app/models` — User, Organization, Host, Variable, Play, FileEntry,
  Run, Setting, ZabbixOption;
- `app/controllers`, `app/views` — UI (ERB + Turbo);
- `app/services` — запуск задач (`RunLauncher`), сборка переменных
  (`RunVariables`), шифрование значений (`VariableCipher`), клиент и
  синхронизатор Zabbix;
- `lib/settings/app_config.rb` — настройки приложения (credentials/ENV);
- `extras/ansible/plugins/become/sudo.py` — become-плагин, совместимый с
  sudo-rs (Ubuntu 26.04+).

## Тесты

```bash
cd /opt/webansible2 && bin/rails test < /dev/null   # ~125 тестов, ~30 c
```
