require "set"

module Zabbix
  # Синхронизация хостов и организаций из Zabbix в ПО.
  #
  # Алгоритм:
  #   1. Берём названия типовых групп из «Типы хостов» (ZabbixOption, category = type).
  #   2. Преобразуем их в id и забираем недеактивированные (status: 0) хосты.
  #   3. Для каждого хоста:
  #        - организация = вторая dot-составляющая имени узла (s-1c.most -> most);
  #        - если точки нет — хост пропускаем;
  #        - создаём/обновляем организацию по точному совпадению имени;
  #        - тип/ОС — первое совпадение групп хоста с «Типы хостов»/«Типы ОС»;
  #        - роли — все совпадения с категориями «Роли хостов».
  #
  # result_callback вызывается после обработки каждого хоста:
  #   ->(processed:, total:)
  class Syncer
    # Классовое состояние «одна синхронизация одновременно» + флаг отмены.
    # Puma однопроцессный (5 потоков), поэтому классовые флаги видны всем запросам;
    # Mutex защищает от гонок между потоками.
    @sync_mutex = Mutex.new
    @syncing = false
    @cancel_requested = false

    class << self
      # Пытается занять «слот» синхронизации. false — если уже идёт другая.
      # При успехе сбрасывает cancel-флаг: «поздняя» отмена предыдущего запуска
      # не должна убить новый.
      def try_begin_sync!
        @sync_mutex.synchronize do
          if @syncing
            false
          else
            @syncing = true
            @cancel_requested = false
            true
          end
        end
      end

      # Освобождает слот и сбрасывает флаг отмены. Вызывать в ensure контроллера.
      def finish_sync!
        @sync_mutex.synchronize do
          @syncing = false
          @cancel_requested = false
        end
      end

      # Запросить остановку идущей синхронизации (кнопка «Отменить»).
      def request_cancel!
        @sync_mutex.synchronize { @cancel_requested = true }
      end

      def cancel_requested?
        @sync_mutex.synchronize { @cancel_requested }
      end
    end

    # Итог синхронизации. cancelled — остановлена по кнопке «Отменить»
    # (счётчики частичные: обработано хостов до отмены). deleted_hosts /
    # deleted_orgs — удалено устаревших записей (только при полном прогоне).
    Result = Struct.new(:total, :created, :updated, :skipped, :errors, :cancelled, :deleted_hosts, :deleted_orgs, keyword_init: true) do
      # Ruby 3.0 — без класса Data с дефолтами; переопределяем initialize
      # ради значений по умолчанию для cancelled и счётчиков удаления.
      def initialize(total:, created:, updated:, skipped:, errors:, cancelled: false, deleted_hosts: 0, deleted_orgs: 0)
        super
      end

      def to_summary
        { done: true, total: total, created: created, updated: updated, skipped: skipped, errors: errors, cancelled: cancelled, deleted_hosts: deleted_hosts, deleted_orgs: deleted_orgs }
      end
    end

    # Хост без организации (нет точки в имени) — не тихий пропуск, а видимая
    # ошибка для админа: попадает в errors (красная строка в модалке) и в skipped.
    class HostWithoutOrganizationError < StandardError; end

    # Человекочитаемые описания нарушений NOT NULL-ограничений (колонка → сообщение).
    # Показываются админу в модалке синхронизации вместо сырого текста исключения.
    NOT_NULL_MESSAGES = {
      "hosts.ip"      => "Не указан IP-адрес",
      "hosts.name"    => "Не указано имя",
      "hosts.type"    => "Не указан тип хоста",
      "hosts.os_type" => "Не указан тип ОС"
    }.freeze

    def initialize(result_callback: nil, client: nil)
      @result_callback = result_callback
      @client = client
    end

    attr_reader :result

    def run
      url = Zabbix::Settings.url
      key = Zabbix::Settings.api_key
      raise "Zabbix не настроен (не указан адрес или ключ)" if url.blank? || key.blank?

      client = @client || Client.new(url: url, api_key: key, insecure_ssl: Zabbix::Settings.insecure_ssl?)
      type_group_names = enabled_values("type")
      raise "Не заданы «Типы хостов» — заполните настройки категорий" if type_group_names.empty?

      group_ids = fetch_group_ids(client, type_group_names)
      hosts = client.host_get(groupids: group_ids, status: 0)
      total = hosts.size
      Rails.logger.info("[ZabbixSync] Zabbix ответил: групп=#{group_ids.inspect} хостов=#{total}")

      result = Result.new(total: total, created: 0, updated: 0, skipped: 0, errors: [])
      hosts.each_with_index do |zhost, index|
        # Проверка отмены в начале итерации: текущий хост доделывается до конца,
        # поэтому частичное состояние БД всегда чистое.
        break if Zabbix::Syncer.cancel_requested?

        processed = index + 1
        begin
          outcome = upsert_host(zhost)
          case outcome
          when :created then result.created += 1
          when :updated then result.updated += 1
          else result.skipped += 1
          end
        rescue => e
          result.errors << { name: zhost_name(zhost), message: friendly_message(e, zhost) }
          result.skipped += 1
        ensure
          @result_callback&.call(processed: processed, total: total)
        end
      end

      # Отмена могла прийти и после последнего хоста (гонка с завершением) —
      # помечаем результат в любом случае; следующий try_begin_sync! сбросит флаг.
      cancelled = Zabbix::Syncer.cancel_requested?
      result.cancelled = true if cancelled

      # Удаление устаревших записей — только при полном прогоне без отмены:
      # после отмены состояние БД частичное, удалять по нему нельзя. Пустой
      # ответ Zabbix (сбой API, пустые группы) тоже не повод сносить всё.
      if !cancelled && hosts.any?
        remove_stale_records(hosts, result)
      elsif !cancelled
        Rails.logger.warn("[ZabbixSync] Zabbix вернул 0 хостов — удаление устаревших записей пропущено")
      end

      @result = result
      result
    end

    private

    # Значения (названия групп в Zabbix) активных опций категории.
    def enabled_values(category)
      ZabbixOption.by_category(category).where(enabled: true).order(:label).pluck(:value)
    end

    def fetch_group_ids(client, names)
      Array(client.hostgroup_get(names: names)).map { |g| g["groupid"] }
    end

    def zhost_name(zhost)
      (zhost.is_a?(Hash) ? zhost["host"] : nil).to_s
    end

    # Имя организации = вторая dot-составляющая имени узла.
    # s-1c.most -> most ; s-dc.sanes-office.temp -> sanes-office .
    def organization_name(hostname)
      return nil if hostname.blank?
      hostname.split(".").fetch(1, nil)
    end

    def host_groups(zhost)
      Array(zhost["groups"]).map { |g| g["name"] }.to_set
    end

    def first_match(set, ordered_values)
      ordered_values.find { |value| set.include?(value) }
    end

    def interface_ip(zhost)
      interfaces = Array(zhost["interfaces"])
      iface = interfaces.find { |i| i["main"] == true } || interfaces.first
      iface && iface["ip"].to_s
    end

    # Переводит исключение при сохранении хоста в короткое человекочитаемое описание.
    # Работает по тексту сообщения (формат «SQLite3::ConstraintException: …» может
    # отличаться от версии к версии), поэтому матчим подстроку, а не класс исключения.
    def friendly_message(e, zhost)
      msg = e.message.to_s
      if (m = msg.match(/NOT NULL constraint failed: (\S+)/))
        NOT_NULL_MESSAGES.fetch(m[1]) { "#{m[1].split(".").last} не указан" }
      elsif msg.include?("UNIQUE constraint failed: hosts.ip")
        unique_ip_message(zhost)
      else
        # Неизвестная ошибка — показываем как есть, ничего не скрываем.
        msg
      end
    end

    # Для дублирующегося IP указываем сам адрес и хост-владельца (если найден),
    # чтобы админ сразу понимал, что исправлять.
    def unique_ip_message(zhost)
      ip = interface_ip(zhost)
      owner = Host.find_by(ip: ip) if ip.present?
      if owner && owner.name != zhost_name(zhost)
        "IP-адрес #{ip} уже используется хостом #{owner.name}"
      else
        "IP-адрес #{ip} уже используется другим хостом"
      end
    end

    def upsert_host(zhost)
      name = zhost_name(zhost)
      org_name = organization_name(name)
      # Без точки в имени организацию определить нельзя — сообщаем админу явно.
      raise HostWithoutOrganizationError, "Не указана организация (нет точки в имени хоста)" if org_name.blank?

      groups = host_groups(zhost)
      type = first_match(groups, enabled_values("type"))
      os_type = first_match(groups, enabled_values("os_type"))
      roles = role_matches(groups)

      organization = find_or_create_org(org_name)
      attributes = {
        name: name,
        ip: interface_ip(zhost),
        type: type,
        os_type: os_type,
        role: roles,
        organization_id: organization.id
      }

      host = Host.find_or_initialize_by(name: name)
      was_persisted = host.persisted?
      # Источник фиксируем только при создании; существующий хост (в т.ч. ручной,
      # совпавший по имени) не перекрашиваем — source отвечает на «откуда создан».
      attributes[:source] = Host::SOURCE_ZABBIX unless was_persisted
      host.assign_attributes(attributes)
      host.save!(validate: false)
      was_persisted ? :updated : :created
    end

    # Все роли, группы которых есть у узла сети.
    def role_matches(groups)
      ZabbixOption.by_category("role").where(enabled: true).order(:label).pluck(:value)
        .select { |value| groups.include?(value) }
    end

    def find_or_create_org(name)
      # Существующую организацию (в т.ч. ручную, совпавшую по имени) не перекрашиваем.
      Organization.find_by(name: name) || Organization.create!(name: name, source: Organization::SOURCE_ZABBIX)
    end

    # Удаляет из БД то, чего больше нет в ответе Zabbix (полный прогон без отмены):
    #   - хосты с источником "zabbix", которых нет в списке — удалены/деактивированы
    #     в Zabbix или перенесены в группы вне «Типов хостов»; ручные не трогаем;
    #   - zabbix-организации, ставшие пустыми после удаления хостов (нет ни хостов,
    #     ни файлов, ни переменных) — пользовательские данные их сохраняют.
    def remove_stale_records(zhosts, result)
      zabbix_names = zhosts.map { |z| zhost_name(z) }.to_set

      stale_hosts = Host.from_zabbix.where.not(name: zabbix_names.to_a)
      result.deleted_hosts = stale_hosts.count
      stale_hosts.destroy_all # каскадом удаляет переменные хоста

      empty_orgs = Organization.from_zabbix.select(&:empty?)
      result.deleted_orgs = empty_orgs.size
      empty_orgs.each { |org| org.destroy! }

      if result.deleted_hosts.positive? || result.deleted_orgs.positive?
        Rails.logger.info("[ZabbixSync] удалено устаревших: хостов=#{result.deleted_hosts} организаций=#{result.deleted_orgs}")
      end
    end
  end
end