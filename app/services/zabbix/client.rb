# Обёртка над JSON-RPC API Zabbix.
# Аутентификация — API-ключом (поле "auth"), без вызова user.login.
# Транспорт (HTTP) можно инъектить для тестов: объект с методом call(body_json_string).
require "net/http"
require "openssl"

module Zabbix
  class Client
    class Error < StandardError; end

    DEFAULT_TIMEOUT = 15

    # insecure_ssl: отключить проверку TLS-сертификата (для внутренних Zabbix
    # с самоподписанным сертификатом). По умолчанию проверка включена.
    def initialize(url:, api_key:, timeout: DEFAULT_TIMEOUT, transport: nil, insecure_ssl: false)
      @url = url.to_s.chomp("/")
      @api_key = api_key
      @timeout = timeout
      @transport = transport
      @insecure_ssl = insecure_ssl
    end

    attr_reader :insecure_ssl

    # Отправляет JSON-RPC запрос и возвращает body["result"].
    # При наличии блока "error" в ответе — поднимает Zabbix::Client::Error.
    def call(method, params = {})
      payload = {
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params,
        "id" => 1
      }
      payload["auth"] = @api_key if @api_key.present?

      body = execute(payload)
      error = body.is_a?(Hash) ? body["error"] : nil
      raise Error.new(error["message"]) if error

      body.is_a?(Hash) ? body["result"] : body
    end

    # Списки групп по именам. Нужны, чтобы получить id типовых групп для фильтрации хостов.
    def hostgroup_get(names:)
      call("hostgroup.get", filter: { name: names }, output: %w[groupid name])
    end

    # Недеактивированные (status: 0) хосты из указанных групп вместе со всеми
    # группами и интерфейсами. Метод Zabbix API — host.get (единоличная форма).
    # Фильтр по status передаётся через filter: у host.get нет топового параметра
    # status, а неизвестные параметры Zabbix молча игнорирует — тогда в ответ
    # приходят и деактивированные хосты.
    def host_get(groupids:, status: 0)
      call("host.get",
        groupids: groupids,
        filter: { "status" => status },
        output: ["host"],
        selectGroups: "extend",
        selectInterfaces: "extend")
    end

    private

    def execute(payload)
      raw = @transport ? @transport.call(payload.to_json) : http_post(payload.to_json)
      JSON.parse(raw)
    rescue JSON::ParserError => e
      raise Error, "Некорректный ответ Zabbix: #{e.message}"
    end

    def http_post(body)
      uri = URI("#{@url}/api_jsonrpc.php")
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @insecure_ssl
      end
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = body

      response = http.request(request)
      raise Error, "Ошибка HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end