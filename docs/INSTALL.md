# Установка WebAnsible 2 v0.1

## Требования

- Linux-сервер с systemd (проверено на Ubuntu 24.04);
- Ruby 3.0.x и заголовки для сборки гемов:
  `apt install ruby-full build-essential libsqlite3-dev`;
- Bundler: `gem install bundler`;
- Ansible (рекомендуется ansible-core >= 2.17 — become-плагин из комплекта
  является тенью стандартного плагина этой версии);
- git.

## 1. Установка приложения

```bash
git clone https://github.com/NorthBridgeKholmsk/webansible2.git /opt/webansible2
cd /opt/webansible2
bundle install
bin/rails db:prepare   # создаёт SQLite-БД и применяет миграции
bin/rails db:seed      # создаёт пользователя admin/admin — сразу смените пароль!
```

## 2. Ansible и become-плагин

Приложение запускает `ansible-playbook` от имени root. Если хостам нужна
эскалация прав по паролю, поставьте прилагаемый become-плагин (совместим с
sudo-rs из поставки Ubuntu 26.04+):

```bash
mkdir -p ~/.ansible/plugins/become
cp /opt/webansible2/extras/ansible/plugins/become/sudo.py ~/.ansible/plugins/become/
```

Зачем он нужен: sudo-rs в не-TTY режиме оборачивает даже кастомный промпт
пароля собственной рамкой, и стандартный плагин sudo её не распознаёт —
запуск падает с ошибкой «Timeout (12s) waiting for privilege escalation
prompt». Плагин из комплекта ищет промпт по подстроке и работает одинаково
с классическим sudo и sudo-rs.

Проверка ключей хостов отключается на каждый запуск: приложение генерирует
собственный `ansible.cfg` (UserKnownHostsFile=/dev/null) в рабочем каталоге
запуска, поэтому глобальная настройка Ansible не требуется.

## 3. systemd-сервис

Файл `/etc/systemd/system/webansible2.service`:

```ini
[Unit]
Description=Web interface for Ansible 2 (/opt/webansible2)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webansible2
Environment=RAILS_ENV=development
# stdin в /dev/null: dev-Gemfile содержит debug, который при старте ждёт
# stdin; с /dev/null получает EOF и продолжает загрузку.
StandardInput=null
ExecStart=/opt/webansible2/bin/rails server -b 0.0.0.0 -p 3000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now webansible2
```

Порт задаётся в `ExecStart` (`-p 3000`).

## 4. Проверка

```bash
systemctl status webansible2
ss -tlnp | grep ':3000'
curl -sI http://127.0.0.1:3000/ | head -1    # HTTP 200 или редирект на /login
journalctl -u webansible2 -n 50 --no-pager
```

Откройте `http://<сервер>:3000`, войдите под admin и смените пароль.

## Настройка (в UI)

- Раздел «Настройки»: название приложения, путь к ansible-playbook, тема;
  Zabbix — URL, API-токен, опция игнорировать ошибки сертификата SSL.
- Настройки хранятся в базе данных (таблица `settings`), переживают
  перезапуск и деплой.

## Зашифрованные переменные

Значения чувствительных переменных шифруются AES-256-GCM. Ключ берётся по
приоритету: `credentials[:variables_encryption_key]` → переменная окружения
`VARIABLES_ENCRYPTION_KEY` → `secret_key_base`. Смена ключа делает все ранее
сохранённые зашифрованные значения нечитаемыми — ротацию делайте осознанно.

## Интеграция с Zabbix

В «Настройках» укажите URL и API-токен; синхронизация запускается из UI с
отображением прогресса. Хосты/организации, пришедшие из Zabbix,
помечаются источником `zabbix`.

## Частые проблемы

- **EADDRINUSE** — порт занят другим процессом: `ss -tlnp | grep :3000`;
- **«Timeout (12s) waiting for privilege escalation prompt»** — become-плагин
  не установлен в домашнем каталоге пользователя, от которого работает
  приложение, или версия Ansible слишком старая;
- **REMOTE HOST IDENTIFICATION HAS CHANGED** — не должно происходить: каждый
  запуск использует собственный `ansible.cfg` с UserKnownHostsFile=/dev/null;
  проверьте права на рабочий каталог запуска;
- **Устаревшие стили/скрипты в UI** — ассеты собираются Sprockets по
  требованию; сделайте жёсткую перезагрузку страницы (Ctrl+Shift+R);
- **Приложение зависает при старте под systemd** — убедитесь, что в юните
  есть `StandardInput=null`.

## Тесты

```bash
cd /opt/webansible2 && bin/rails test < /dev/null
```
