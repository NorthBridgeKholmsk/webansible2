require "test_helper"

# Шифрование значений переменных типа «зашифрованная»:
# round-trip, идемпотентность, детекция префикса, legacy-plaintext насквозь.
class VariableCipherTest < ActiveSupport::TestCase
  test "encrypt/decrypt возвращает исходное значение" do
    secret = "p@ssw0rd-ключ!"
    encrypted = VariableCipher.encrypt(secret)
    assert VariableCipher.encrypted?(encrypted)
    refute_equal secret, encrypted
    assert_equal secret, VariableCipher.decrypt(encrypted)
  end

  test "encrypt идемпотентен: шифротекст не шифруется повторно" do
    once = VariableCipher.encrypt("secret")
    assert_equal once, VariableCipher.encrypt(once)
  end

  test "строка без префикса (обычная переменная / legacy) читается как есть" do
    refute VariableCipher.encrypted?("plain value")
    assert_equal "plain value", VariableCipher.decrypt("plain value")
    assert_nil VariableCipher.decrypt(nil)
    assert_nil VariableCipher.encrypt(nil)
  end

  test "для одного значения шифротексты разные (случайный IV)" do
    assert_not_equal VariableCipher.encrypt("same"), VariableCipher.encrypt("same")
  end
end
