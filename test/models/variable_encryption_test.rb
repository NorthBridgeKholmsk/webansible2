require "test_helper"

# Типы переменных (обычная / зашифрованная) для обеих таблиц:
# - обычная хранится в plaintext;
# - зашифрованная — только шифротекст с префиксом, читается прозрачно;
# - пустое значение не стирает сохранённый секрет;
# - смена флага конвертирует формат хранения в обе стороны.
class VariableEncryptionTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "enc-org-#{SecureRandom.hex(4)}")
    @host = Host.create!(
      name: "enc-host-#{SecureRandom.hex(4)}", ip: "10.9.9.9",
      type: "Server", os_type: "Linux", role: ["web"], organization_id: @organization.id
    )
  end

  test "обычная переменная хоста хранится в plaintext" do
    v = @host.variables.create!(name: "env", value: "production")
    refute VariableCipher.encrypted?(v.read_attribute(:value))
    assert_equal "production", v.read_attribute(:value)
    assert_equal "production", v.value
  end

  test "зашифрованная переменная хоста хранится только как шифротекст" do
    v = @host.variables.create!(name: "db_password", value: "S3cret!", encrypted: true)
    raw = v.read_attribute(:value)
    assert VariableCipher.encrypted?(raw)
    refute_includes raw, "S3cret!"
    assert_equal "S3cret!", v.value
  end

  test "пустое значение не стирает секрет уже сохранённой зашифрованной переменной" do
    v = @host.variables.create!(name: "db_password", value: "S3cret!", encrypted: true)
    before_raw = v.read_attribute(:value)

    assert v.update(value: "")
    v.reload
    assert_equal before_raw, v.read_attribute(:value)
    assert_equal "S3cret!", v.value
  end

  test "ненулевое значение обновляет секрет зашифрованной переменной" do
    v = @host.variables.create!(name: "db_password", value: "old-pass", encrypted: true)

    assert v.update(value: "new-pass")
    v.reload
    assert_equal "new-pass", v.value
    refute_includes v.read_attribute(:value), "new-pass"
  end

  test "снятие флага конвертирует зашифрованную переменную в plaintext" do
    v = @host.variables.create!(name: "db_password", value: "S3cret!", encrypted: true)

    assert v.update(encrypted: false)
    v.reload
    refute VariableCipher.encrypted?(v.read_attribute(:value))
    assert_equal "S3cret!", v.value
  end

  test "включение флага шифрует существующий plaintext" do
    v = @host.variables.create!(name: "env", value: "production")

    assert v.update(encrypted: true)
    v.reload
    assert VariableCipher.encrypted?(v.read_attribute(:value))
    assert_equal "production", v.value
  end

  test "пустое значение при включении шифрования не стирает plaintext-пароль" do
    # Сценарий инцидента: переменная хранится в открытом виде, форма отправляет
    # пустое поле (JS сбросил его при отметке чекбокса) + encrypted=true.
    v = @host.variables.create!(name: "db_password", value: "S3cret!")

    assert v.update(value: "", encrypted: true)
    v.reload
    assert VariableCipher.encrypted?(v.read_attribute(:value))
    assert_equal "S3cret!", v.value
  end

  test "общая переменная: зашифрованная хранится как шифротекст, пустое значение не стирает" do
    cv = CommonVariable.create!(name: "global_secret_#{SecureRandom.hex(3)}", value: "C0mm0n!", encrypted: true)
    assert VariableCipher.encrypted?(cv.read_attribute(:value))
    refute_includes cv.read_attribute(:value), "C0mm0n!"

    before_raw = cv.read_attribute(:value)
    assert cv.update(value: "")
    cv.reload
    assert_equal before_raw, cv.read_attribute(:value)
    assert_equal "C0mm0n!", cv.value
  end

  test "общая переменная: смена флага конвертирует формат в обе стороны" do
    cv = CommonVariable.create!(name: "global_toggle_#{SecureRandom.hex(3)}", value: "Plain123")
    assert cv.update(encrypted: true)
    cv.reload
    assert VariableCipher.encrypted?(cv.read_attribute(:value))
    assert_equal "Plain123", cv.value

    assert cv.update(encrypted: false)
    cv.reload
    refute VariableCipher.encrypted?(cv.read_attribute(:value))
    assert_equal "Plain123", cv.value
  end

  test "общая переменная: пустое значение при включении шифрования не стирает plaintext" do
    cv = CommonVariable.create!(name: "global_pw_#{SecureRandom.hex(3)}", value: "Plain123")

    assert cv.update(value: "", encrypted: true)
    cv.reload
    assert VariableCipher.encrypted?(cv.read_attribute(:value))
    assert_equal "Plain123", cv.value
  end

  test "новая зашифрованная переменная с пустым значением не хранит шифротекст пустоты" do
    # Сценарий инцидента: чекбокс «зашифровать» отмечен, поле значения пустое.
    # Раньше хранилось enc1:<пусто>, которое расшифровывалось в "" и по правилу
    # «пусто = не задано» выпадало из инвентаря запуска (undefined variable).
    v = @host.variables.create!(name: "future_secret", value: "", encrypted: true)
    assert_nil v.read_attribute(:value)

    # Дальнейшее заполнение значения работает штатно.
    assert v.update(value: "S3cret!")
    v.reload
    assert VariableCipher.encrypted?(v.read_attribute(:value))
    assert_equal "S3cret!", v.value
  end

  test "общая переменная: новая зашифрованная с пустым значением не хранит шифротекст пустоты" do
    cv = CommonVariable.create!(name: "future_common_#{SecureRandom.hex(3)}", value: "", encrypted: true)
    assert_nil cv.read_attribute(:value)

    assert cv.update(value: "C0mm0n!")
    cv.reload
    assert VariableCipher.encrypted?(cv.read_attribute(:value))
    assert_equal "C0mm0n!", cv.value
  end
end
