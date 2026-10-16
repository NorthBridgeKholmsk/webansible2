require "test_helper"

# Фейковый клиент Zabbix (без HTTP): возвращает подготовленные группы/хосты.
class FakeZabbixClient
  def initialize(groups: [], hosts: [])
    @groups = groups
    @hosts = hosts
  end

  def hostgroup_get(names:)
    @groups.select { |g| names.include?(g["name"]) }
  end

  def host_get(groupids:, status: 0)
    @hosts
  end
end

# Поле «Источник» (manual/zabbix) и очистка устаревших записей при синке:
# - source фиксируется только при создании, существующие записи не перекрашиваются;
# - при полном прогоне без отмены удаляются zabbix-хосты, отсутствующие в ответе,
#   и ставшие пустыми zabbix-организации (без хостов/файлов/переменных);
# - ручные записи не трогаются; пустой ответ или отмена — ничего не удаляется.
class Zabbix::SyncerSourceTest < ActiveSupport::TestCase
  setup do
    # Настройки подключения нужны для Syncer#run даже с фейковым клиентом.
    Zabbix::Settings.apply(url: "https://zbx.test", api_key: "test-key")
    type_opt = ZabbixOption.find_or_create_by!(category: "type", value: "Web-servers", label: "Web-серверы")
    type_opt.update_columns(enabled: true)
    # Тип ОС обязателен (NOT NULL в БД): хост должен совпасть с активной опцией.
    os_opt = ZabbixOption.find_or_create_by!(category: "os_type", value: "Linux", label: "Linux")
    os_opt.update_columns(enabled: true)
  end

  def run_sync(hosts:)
    client = FakeZabbixClient.new(
      groups: [
        { "groupid" => "10", "name" => "Web-servers" },
        { "groupid" => "20", "name" => "Linux" }
      ],
      hosts: hosts
    )
    Zabbix::Syncer.new(client: client).run
  end

  def zhost(name, ip:)
    {
      "host" => name,
      "groups" => [{ "name" => "Web-servers" }, { "name" => "Linux" }],
      "interfaces" => [{ "ip" => ip, "main" => true }]
    }
  end

  test "по умолчанию source = manual; некорректное значение отклоняется" do
    org = Organization.create!(name: "def-org-#{SecureRandom.hex(3)}")
    assert_equal Organization::SOURCE_MANUAL, org.source

    host = Host.create!(name: "s-def.manual", ip: "10.9.0.1", type: "Web-servers", os_type: "Linux", role: ["web"], organization_id: org.id)
    assert_equal Host::SOURCE_MANUAL, host.source

    bad_org = Organization.new(name: "bad-src-#{SecureRandom.hex(3)}", source: "hack")
    assert_not bad_org.valid?
    assert bad_org.errors[:source].any?
  end

  test "хосты и организации, созданные синком, получают source zabbix" do
    result = run_sync(hosts: [zhost("s-1c.sync-org", ip: "10.9.0.2")])
    assert_equal 1, result.created

    host = Host.find_by(name: "s-1c.sync-org")
    org = Organization.find_by(name: "sync-org")
    assert_equal Host::SOURCE_ZABBIX, host.source
    assert_equal Organization::SOURCE_ZABBIX, org.source
  end

  test "существующие ручные записи не перекрашиваются при обновлении" do
    org = Organization.create!(name: "manual-org-#{SecureRandom.hex(3)}")
    Host.create!(name: "s-1c.manual-org", ip: "10.9.0.3", type: "Web-servers", os_type: "Linux", role: ["web"], organization_id: org.id)

    result = run_sync(hosts: [zhost("s-1c.manual-org", ip: "10.9.0.4")])
    assert_equal 1, result.updated

    assert_equal Organization::SOURCE_MANUAL, org.reload.source
    assert_equal Host::SOURCE_MANUAL, Host.find_by(name: "s-1c.manual-org").source
  end

  test "устаревшие zabbix-хосты удаляются, ручные сохраняются" do
    run_sync(hosts: [zhost("s-1c.gone", ip: "10.9.0.5"), zhost("s-1c.stays", ip: "10.9.0.6")])

    # Ручной хост, которого нет в ответе Zabbix, — под контролем админа.
    manual_org = Organization.create!(name: "manual-org2-#{SecureRandom.hex(3)}")
    Host.create!(name: "s-1c.gone.manual", ip: "10.9.0.7", type: "Web-servers", os_type: "Linux", role: ["web"], organization_id: manual_org.id)

    result = run_sync(hosts: [zhost("s-1c.stays", ip: "10.9.0.8")])
    assert_equal 1, result.deleted_hosts
    assert_nil Host.find_by(name: "s-1c.gone")
    assert Host.exists?(name: "s-1c.stays")
    assert Host.exists?(name: "s-1c.gone.manual")
  end

  test "пустая zabbix-организация удаляется после удаления её хоста" do
    run_sync(hosts: [zhost("s-1c.empty-org", ip: "10.9.0.9"), zhost("s-1c.kept-org", ip: "10.9.0.10")])

    result = run_sync(hosts: [zhost("s-1c.kept-org", ip: "10.9.0.11")])
    assert_equal 1, result.deleted_hosts
    assert_equal 1, result.deleted_orgs
    assert_nil Organization.find_by(name: "empty-org")
    assert Organization.exists?(name: "kept-org")
  end

  test "zabbix-организация с пользовательскими данными не удаляется" do
    run_sync(hosts: [zhost("s-1c.data-org", ip: "10.9.0.12"), zhost("s-1c.other", ip: "10.9.0.13")])
    org = Organization.find_by(name: "data-org")
    Variable.create!(variableable: org, name: "env", value: "prod")

    result = run_sync(hosts: [zhost("s-1c.other", ip: "10.9.0.14")])
    assert_equal 1, result.deleted_hosts # s-1c.data-org устарел
    assert_equal 0, result.deleted_orgs  # data-org не пуста (есть переменная) — остаётся
    assert Organization.exists?(name: "data-org")
  end

  test "пустая ручная организация не удаляется" do
    lonely = Organization.create!(name: "lonely-manual-#{SecureRandom.hex(3)}")
    result = run_sync(hosts: [zhost("s-1c.some", ip: "10.9.0.15")])
    assert_equal 0, result.deleted_orgs
    assert Organization.exists?(name: lonely.name)
  end

  test "пустой ответ Zabbix ничего не удаляет" do
    run_sync(hosts: [zhost("s-1c.keep", ip: "10.9.0.16")])

    result = run_sync(hosts: [])
    assert_equal 0, result.deleted_hosts
    assert_equal 0, result.deleted_orgs
    assert Host.exists?(name: "s-1c.keep")
    assert Organization.exists?(name: "keep")
  end

  test "отменённый синк ничего не удаляет" do
    run_sync(hosts: [zhost("s-1c.victim", ip: "10.9.0.17"), zhost("s-1c.keep2", ip: "10.9.0.18")])

    Zabbix::Syncer.request_cancel!
    begin
      # victim отсутствует в ответе — без отмены был бы удалён как устаревший.
      result = run_sync(hosts: [zhost("s-1c.keep2", ip: "10.9.0.19")])
    ensure
      Zabbix::Syncer.finish_sync!
    end

    assert result.cancelled
    assert_equal 0, result.deleted_hosts
    assert Host.exists?(name: "s-1c.victim")
  end
end
