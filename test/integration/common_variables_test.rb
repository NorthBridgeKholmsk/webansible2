require "test_helper"

# Общие переменные: страница списка, пункт меню в «Инвентаризации»,
# пакетное сохранение (создание/обновление/удаление), игнор пустых имён.
class CommonVariablesTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect
  end

  test "страница общих переменных открывается и показывает пустой список" do
    get common_variables_path
    assert_response :success
    assert_match "Общие переменные", @response.body
    # Серверных строк нет (в инлайн-скрипте шаблон строки есть, но без числового id).
    assert_equal 0, @response.body.scan(%r{<input type="hidden" name="items\[\]\[id\]" value="\d+"}).size
  end

  test "пункт меню «Общие переменные» есть на страницах инвентаризации" do
    get hosts_path
    assert_response :success
    assert_match "Общие переменные", @response.body
    assert_match common_variables_path, @response.body
  end

  test "новые строки создаются при сохранении" do
    patch common_variables_path, params: { items: [
      { name: "env", value: "prod" },
      { name: "domain", value: "mido-office.local" }
    ] }
    assert_response :redirect
    assert_equal 2, CommonVariable.count
    assert_equal "prod", CommonVariable.find_by(name: "env").value
  end

  test "существующие строки обновляются, отсутствующие удаляются" do
    v1 = CommonVariable.create!(name: "a", value: "1")
    CommonVariable.create!(name: "b", value: "2")

    patch common_variables_path, params: { items: [
      { id: v1.id.to_s, name: "a", value: "updated" }
    ] }
    assert_response :redirect
    assert_equal 1, CommonVariable.count
    assert_equal "updated", v1.reload.value
  end

  test "строки с пустым именем игнорируются (запись удаляется)" do
    CommonVariable.create!(name: "a", value: "1")

    patch common_variables_path, params: { items: [
      { name: "", value: "x" }
    ] }
    assert_response :redirect
    assert_equal 0, CommonVariable.count
  end

  test "дубликаты имён в одной форме сохраняются один раз" do
    patch common_variables_path, params: { items: [
      { name: "env", value: "first" },
      { name: "env", value: "second" }
    ] }
    assert_response :redirect
    assert_equal 1, CommonVariable.count
    assert_equal "first", CommonVariable.find_by(name: "env").value
  end

  test "пустая форма удаляет все переменные" do
    CommonVariable.create!(name: "a", value: "1")

    patch common_variables_path, params: { items: [] }
    assert_response :redirect
    assert_equal 0, CommonVariable.count
  end
end
