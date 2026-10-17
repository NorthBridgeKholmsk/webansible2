require "test_helper"

# Плейбуки — конструктор из плеев с ветвлением по ОС:
# создание через форму (вложенные атрибуты в два уровня), список с бейджами ОС,
# порядок плеев внутри ветвления, удаление ветвлений и очистка ссылок при удалении плея.
class PlaybooksTest < ActionDispatch::IntegrationTest
  setup do
    User.find_or_create_by!(login: "admin") do |user|
      user.password = "admin"
      user.password_confirmation = "admin"
      user.role = "admin"
      user.active = true
    end
    post sessions_path, params: { login: "admin", password: "admin" }
    assert_response :redirect

    @p1 = Play.create!(name: "pl-pb-1-#{SecureRandom.hex(2)}", os_type: "ubuntu")
    @p2 = Play.create!(name: "pl-pb-2-#{SecureRandom.hex(2)}", os_type: "ubuntu")
    @p3 = Play.create!(name: "pl-pb-3-#{SecureRandom.hex(2)}", os_type: "windows")
  end

  test "плейбук создаётся с двумя ветвлениями по ОС и порядком плеев" do
    post playbooks_path, params: { playbook: { name: "pb-ctor-#{SecureRandom.hex(3)}", description: "тест", sections_attributes: [
      { os_type: "ubuntu", section_plays_attributes: [{ play_id: @p2.id, position: 0 }, { play_id: @p1.id, position: 1 }] },
      { os_type: "windows", section_plays_attributes: [{ play_id: @p3.id, position: 0 }] }
    ] } }
    assert_response :redirect

    pb = Playbook.last
    assert_equal 2, pb.sections.count
    ubuntu = pb.sections.find_by(os_type: "ubuntu")
    windows = pb.sections.find_by(os_type: "windows")
    assert_not_nil ubuntu
    assert_not_nil windows
    # Порядок плеев внутри ветвления — по position (как в форме).
    assert_equal [@p2.id, @p1.id], ubuntu.section_plays.map(&:play_id)
    assert_equal [@p3.id], windows.section_plays.map(&:play_id)
  end

  test "плейбук без имени не создаётся" do
    post playbooks_path, params: { playbook: { name: "", sections_attributes: [] } }
    assert_response :unprocessable_entity
  end

  test "список показывает имя и ОС ветвлений, в которые добавлены плеи" do
    pb = Playbook.create!(name: "pb-list-#{SecureRandom.hex(3)}")
    s1 = pb.sections.create!(os_type: "ubuntu")
    s1.section_plays.create!(play: @p1, position: 0)
    pb.sections.create!(os_type: "windows") # пустое ветвление — в списке не отображается

    get playbooks_path
    assert_response :success
    body = @response.body
    assert_match(pb.name, body)
    assert_match(/<span class="badge bg-secondary[^"]*">ubuntu<\/span>/, body)
    assert_no_match(/<span class="badge bg-secondary[^"]*">windows<\/span>/, body)
  end

  test "show отображает ветвления с упорядоченными плеями" do
    pb = Playbook.create!(name: "pb-show-#{SecureRandom.hex(3)}")
    s = pb.sections.create!(os_type: "ubuntu")
    s.section_plays.create!(play: @p2, position: 0)
    s.section_plays.create!(play: @p1, position: 1)

    get playbook_path(pb)
    assert_response :success
    body = @response.body
    # Плей с position 0 идёт раньше.
    assert_includes body, @p2.name
    assert_includes body, @p1.name
    assert_operator body.index(@p2.name), :<, body.index(@p1.name)
  end

  test "редактирование: _destroy убирает ветвление и плей из него" do
    pb = Playbook.create!(name: "pb-edit-#{SecureRandom.hex(3)}")
    s1 = pb.sections.create!(os_type: "ubuntu")
    sp = s1.section_plays.create!(play: @p1, position: 0)
    s2 = pb.sections.create!(os_type: "windows")

    patch playbook_path(pb), params: { playbook: { name: pb.name, sections_attributes: [
      { id: s1.id, os_type: "ubuntu", section_plays_attributes: [{ id: sp.id, play_id: @p1.id, position: 0, _destroy: "1" }] },
      { id: s2.id, os_type: "windows", _destroy: "1" }
    ] } }
    assert_response :redirect

    pb.reload
    assert_equal 1, pb.sections.count
    assert_equal "ubuntu", pb.sections.first.os_type
    assert_empty pb.sections.first.section_plays
  end

  test "удаление плея убирает его из всех плейбуков" do
    pb = Playbook.create!(name: "pb-del-#{SecureRandom.hex(3)}")
    s = pb.sections.create!(os_type: "ubuntu")
    s.section_plays.create!(play: @p1, position: 0)

    @p1.destroy
    assert_empty PlaybookSectionPlay.all
  end
end