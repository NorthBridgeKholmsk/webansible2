require "test_helper"

class ZabbixClientTest < ActiveSupport::TestCase
  def build_client(transport:, api_key: "secret-key")
    Zabbix::Client.new(url: "https://zbx.example.com", api_key: api_key, transport: transport)
  end

  test "call строит envelope JSON-RPC с ключом и возвращает result" do
    captured = nil
    client = build_client(transport: ->(body) {
      captured = JSON.parse(body)
      JSON.generate("result" => [{"groupid" => 3}])
    })

    result = client.call("hostgroup.get", filter: { name: ["web"] }, output: %w[groupid])

    assert_equal "2.0", captured["jsonrpc"]
    assert_equal "hostgroup.get", captured["method"]
    assert_equal "secret-key", captured["auth"]
    assert_equal [{"groupid" => 3}], result
  end

  test "call поднимает Zabbix::Client::Error при блоке error" do
    client = build_client(transport: ->(_body) { JSON.generate("error" => {"code" => -32602, "message" => "Bad params"}) })
    error = assert_raises(Zabbix::Client::Error) { client.call("hosts.get", {}) }
    assert_match(/Bad params/, error.message)
  end

  test "hostgroup_get передаёт names и output" do
    captured = nil
    client = build_client(transport: ->(body) { captured = JSON.parse(body); JSON.generate([]) })

    client.hostgroup_get(names: ["web", "db"])

    params = captured["params"]
    assert_equal ["web", "db"], params["filter"]["name"]
    assert_equal %w[groupid name], params["output"]
  end

  test "host_get фильтрует по groupids и status (через filter)" do
    captured = nil
    client = build_client(transport: ->(body) { captured = JSON.parse(body); JSON.generate([]) })

    client.host_get(groupids: [1, 2], status: 0)

    assert_equal "host.get", captured["method"]
    params = captured["params"]
    assert_equal [1, 2], params["groupids"]
    # Фильтр по статусу — только через filter: топового параметра status у
    # host.get не существует, и Zabbix неизвестные параметры молча игнорирует.
    assert_equal 0, params.dig("filter", "status")
    refute params.key?("status"), "топовый status не должен передаваться"
    assert_equal "extend", params["selectGroups"]
    assert_equal "extend", params["selectInterfaces"]
  end

  test "insecure_ssl выключен по умолчанию" do
    client = build_client(transport: ->(_body) { JSON.generate("result" => nil) })
    refute client.insecure_ssl
  end

  test "insecure_ssl включается явным параметром" do
    transport = ->(_body) { JSON.generate("result" => nil) }
    client = Zabbix::Client.new(url: "https://zbx.example.com", api_key: "k", transport: transport, insecure_ssl: true)
    assert client.insecure_ssl
  end
end