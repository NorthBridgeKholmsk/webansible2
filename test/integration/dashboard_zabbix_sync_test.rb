require "test_helper"

class DashboardZabbixSyncTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end

    User.find_or_create_by!(login: "editor") do |user|
      user.password = "editor"
      user.password_confirmation = "editor"
      user.role = "editor"
      user.active = true
    end

    # Опции категорий, чтобы Syncer мог построить group_ids.
    ZabbixOption.find_or_create_by!(category: "type", value: "Web-servers", label: "Web-серверы").update_columns(enabled: true)
    Setting.find_or_initialize_by(key: "zabbix_url").update(value: "https://zbx.local")
    Setting.find_or_initialize_by(key: "zabbix_api_key").update(value: "ciphertext-placeholder")
  end

  test "админ запускает синхронизацию и получает поток JSON-lines" do
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    post zabbix_sync_path
    assert_response :success
    # Тело — поток JSON-lines: шаги processed/total и финальная сводка с done.
    assert_match(/("processed"|"total"|processed)/, @response.body)
  end

  test "не-админ не может запустить синхронизацию" do
    post sessions_path, params: { login: "editor", password: "editor" }
    assert_response :redirect

    post zabbix_sync_path
    assert_response :redirect
    assert_equal root_url, @response.location
  end

  test "админ может запросить отмену синхронизации" do
    begin
      post sessions_path, params: { login: "admin", password: "admin" }
      assert_response :redirect

      post zabbix_sync_cancel_path
      assert_response :success
      assert_equal({ "cancelled" => true }, JSON.parse(@response.body))
    ensure
      # Не оставлять флаг отмены для других тестов.
      Zabbix::Syncer.finish_sync!
    end
  end

  test "не-админ не может запросить отмену синхронизации" do
    post sessions_path, params: { login: "editor", password: "editor" }
    assert_response :redirect

    post zabbix_sync_cancel_path
    assert_response :redirect
    assert_equal root_url, @response.location
  end

  test "повторный запуск во время синхронизации не стартует новую" do
    begin
      post sessions_path, params: { login: "admin", password: "admin" }
      assert_response :redirect

      # Имитируем идущую синхронизацию из другой вкладки.
      Zabbix::Syncer.try_begin_sync!
      post zabbix_sync_path
      assert_response :success
      lines = @response.body.strip.split("\n").map { |l| JSON.parse(l) }
      assert_match(/Синхронизация уже выполняется/, @response.body)
      assert_equal "Синхронизация уже выполняется", lines.first["message"]
      assert lines.last["done"]
    ensure
      Zabbix::Syncer.finish_sync!
    end
  end
end