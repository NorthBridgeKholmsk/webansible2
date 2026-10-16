require "test_helper"

# Фейковый клиент Zabbix: возвращает заранее подготовленные списки групп и хостов.
class FakeClient
  # Аргументы последнего вызова host_get — чтобы проверять, с каким фильтром
  # Syncer обращается к Zabbix (например, только активные хосты).
  attr_reader :host_get_args

  def initialize(groups:, hosts:)
    @groups = groups
    @hosts = hosts
  end

  def hostgroup_get(names:)
    @groups
  end

  def host_get(**args)
    @host_get_args = args
    @hosts
  end
end

class ZabbixSyncerTest < ActiveSupport::TestCase
  setup do
    # Настройки подключения, которые Syncer читает через Zabbix::Settings.
    Setting.find_or_initialize_by(key: "zabbix_url").update(value: "https://zbx.local")
    encrypted_key = Zabbix::Settings::Cipher.encrypt("test-key")
    Setting.find_or_initialize_by(key: "zabbix_api_key").update(value: encrypted_key)

    # Опции категорий, определяющие маппинг.
    ZabbixOption.find_or_initialize_by(category: "type", value: "Web-servers").update(label: "Web-серверы", enabled: true)
    ZabbixOption.find_or_initialize_by(category: "type", value: "DB-servers").update(label: "Базы данных", enabled: true)

    ZabbixOption.find_or_initialize_by(category: "os_type", value: "Linux-OS").update(label: "Linux", enabled: true)
    ZabbixOption.find_or_initialize_by(category: "os_type", value: "Windows").update(label: "Windows", enabled: true)

    ZabbixOption.find_or_initialize_by(category: "role", value: "Frontend-role").update(label: "Frontend", enabled: true)
    ZabbixOption.find_or_initialize_by(category: "role", value: "Data-role").update(label: "Data", enabled: true)
  end

  teardown do
    Host.delete_all
    Organization.delete_all
    ZabbixOption.delete_all
    Setting.where(key: ["zabbix_url", "zabbix_api_key"]).delete_all
    # Классовые флаги guard/отмены общие для всего процесса — сбрасываем,
    # чтобы не перетекли в другие тесты.
    Zabbix::Syncer.finish_sync!
  end

  test "создаёт организацию и хост, маппинг по группам" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        {
          "host" => "s-web1.most",
          "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}],
          "interfaces" => [{"ip" => "10.0.0.1", "main" => true}]
        }
      ]
    )

    result = Zabbix::Syncer.new(client: client).run

    assert_equal 1, result.total
    assert_equal 1, result.created
    org = Organization.find_by(name: "most")
    assert org
    host = Host.find_by(name: "s-web1.most")
    assert host
    assert_equal "10.0.0.1", host.ip
    assert_equal "Web-servers", host.type
    assert_equal "Linux-OS", host.os_type
    assert_empty host.role
    assert_equal org.id, host.organization_id
  end

  test "запрашивает у Zabbix только активные хосты (status: 0)" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-web1.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "10.0.0.2", "main" => true}] }
      ]
    )

    Zabbix::Syncer.new(client: client).run

    # Деактивированные хосты не должны попадать в синхронизацию: Syncer передаёт
    # фильтр status клиенту, а тот кладёт его в filter запроса host.get.
    assert_equal 0, client.host_get_args[:status]
  end

  test "роль собирает все совпадения; повторный запуск обновляет хост" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        {
          "host" => "s-app1.sanes-office.temp",
          "groups" => [{"name" => "DB-servers"}, {"name" => "Linux-OS"}, {"name" => "Frontend-role"}],
          "interfaces" => [{"ip" => "10.0.0.9", "main" => true}, {"ip" => "10.0.0.10"}]
        }
      ]
    )

    first = Zabbix::Syncer.new(client: client).run
    assert_equal 1, first.created

    host = Host.find_by(name: "s-app1.sanes-office.temp")
    assert_equal "sanes-office", Organization.find_by(id: host.organization_id).name
    assert_equal "DB-servers", host.type # первое совпадение в «Типы хостов»
    assert_equal ["Frontend-role"], host.role

    second = Zabbix::Syncer.new(client: client).run
    assert_equal 0, second.created
    assert_equal 1, second.updated
    assert_equal 1, Host.count
  end

  test "пропускает хосты без точки в имени и отчитывается о прогрессе" do
    calls = []
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "nodot", "groups" => [], "interfaces" => [] },
        { "host" => "a.b.c", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "1.2.3.4"}] }
      ]
    )

    result = Zabbix::Syncer.new(client: client, result_callback: ->(progress) { calls << [progress[:processed], progress[:total]] }).run

    assert_equal 2, result.total
    assert_equal 1, result.created
    assert_equal 1, result.skipped
    # Хост без организации (нет точки в имени) — красная строка в списке ошибок модалки.
    assert_equal [{ name: "nodot", message: "Не указана организация (нет точки в имени хоста)" }], result.errors
    # Прогресс отдаётся после каждого хоста с общим количеством, известным заранее.
    assert_equal [[1, 2], [2, 2]], calls
  end

  test "выбирает первый интерфейс как IP" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        {
          "host" => "multi.a.b",
          "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}],
          "interfaces" => [{"ip" => "10.0.0.99", "main" => false}, {"ip" => "172.16.0.5", "main" => true}]
        }
      ]
    )

    Zabbix::Syncer.new(client: client).run
    host = Host.find_by(name: "multi.a.b")
    assert_equal "172.16.0.5", host.ip
  end

  test "отсутствие IP-адреса — человекочитаемая ошибка" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-noip.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [] }
      ]
    )

    result = Zabbix::Syncer.new(client: client).run

    assert_equal 1, result.skipped
    assert_equal 0, result.created
    err = result.errors.first
    assert_equal "s-noip.most", err[:name]
    assert_equal "Не указан IP-адрес", err[:message]
  end

  test "отсутствие типа ОС — человекочитаемая ошибка" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-noos.most", "groups" => [{"name" => "Web-servers"}], "interfaces" => [{"ip" => "10.9.9.9", "main" => true}] }
      ]
    )

    result = Zabbix::Syncer.new(client: client).run

    assert_equal 1, result.skipped
    err = result.errors.first
    assert_equal "s-noos.most", err[:name]
    assert_equal "Не указан тип ОС", err[:message]
  end

  test "дублирующийся IP — ошибка с адресом и хостом-владельцем" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-first.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "10.5.5.5", "main" => true}] },
        { "host" => "s-second.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Windows"}], "interfaces" => [{"ip" => "10.5.5.5", "main" => true}] }
      ]
    )

    result = Zabbix::Syncer.new(client: client).run

    assert_equal 1, result.created
    assert_equal 1, result.skipped
    err = result.errors.first
    assert_equal "s-second.most", err[:name]
    assert_equal "IP-адрес 10.5.5.5 уже используется хостом s-first.most", err[:message]
  end

  test "сообщения об ошибках не содержат сырого текста исключений" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-a.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [] },
        { "host" => "s-b.most", "groups" => [{"name" => "Web-servers"}], "interfaces" => [{"ip" => "10.7.7.7", "main" => true}] }
      ]
    )

    result = Zabbix::Syncer.new(client: client).run

    assert_equal 2, result.errors.size
    result.errors.each do |err|
      refute_match(/SQLite3|constraint failed/i, err[:message])
    end
  end

  test "отмена на N-м хосте останавливает цикл и помечает результат" do
    client = FakeClient.new(
      groups: [],
      hosts: [
        { "host" => "s-a.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "10.1.0.1", "main" => true}] },
        { "host" => "s-b.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "10.1.0.2", "main" => true}] },
        { "host" => "s-c.most", "groups" => [{"name" => "Web-servers"}, {"name" => "Linux-OS"}], "interfaces" => [{"ip" => "10.1.0.3", "main" => true}] }
      ]
    )

    Zabbix::Syncer.try_begin_sync!
    result = nil
    begin
      # Отмена запрашивается после первого хоста — через тот же callback, что и стриминг прогресса.
      result = Zabbix::Syncer.new(client: client, result_callback: ->(progress) {
        Zabbix::Syncer.request_cancel! if progress[:processed] == 1
      }).run
    ensure
      Zabbix::Syncer.finish_sync!
    end

    assert result.cancelled
    assert_equal 3, result.total
    # Цикл остановлен: обработан только первый хост.
    assert_equal 1, result.created
    assert_equal 0, result.updated
    assert_empty result.errors
    assert_equal 1, Host.count
    assert_nil Host.find_by(name: "s-c.most")
  end

  test "guard: одна синхронизация одновременно; finish сбрасывает флаги" do
    begin
      assert Zabbix::Syncer.try_begin_sync!
      refute Zabbix::Syncer.try_begin_sync! # слот занят — второй запуск отклонён
      Zabbix::Syncer.request_cancel!
      assert Zabbix::Syncer.cancel_requested?

      Zabbix::Syncer.finish_sync!
      # После finish: слот свободен, а «поздняя» отмена не перетекла в новый запуск.
      assert Zabbix::Syncer.try_begin_sync!
      refute Zabbix::Syncer.cancel_requested?
    ensure
      Zabbix::Syncer.finish_sync!
    end
  end
end