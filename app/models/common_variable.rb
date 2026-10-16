# Общие (глобальные) переменные — пары имя/значение, которые применяются
# ко всем хостам вне зависимости от организации, типа и роли.
class CommonVariable < ApplicationRecord
  validates :name, presence: true
  validates :name, uniqueness: true

  before_save :apply_value_encryption

  # Прозрачное чтение: зашифрованное значение расшифровывается на лету.
  def value
    raw = read_attribute(:value)
    return if raw.nil?
    VariableCipher.encrypted?(raw) ? VariableCipher.decrypt(raw) : raw
  end

  # «Пусто = не менять»: для уже сохранённой зашифрованной переменной пустое
  # значение из формы не стирает хранимый секрет (форма возвращает все строки).
  def value=(new_value)
    return if new_value.blank? && persisted? && encrypted? && VariableCipher.encrypted?(read_attribute(:value))
    super(new_value)
  end

  private

  # Инвариант хранения: encrypted=true -> только шифротекст,
  # encrypted=false -> только plaintext. Смена флага конвертирует формат.
  def apply_value_encryption
    # «Пусто = не менять» при включении шифрования: если значение пришло пустым
    # (в т.ч. форма/JS сбросили поле), а флаг включили этим же сохранением —
    # возвращаем прежнее, иначе пустая отправка затирает хранимый пароль.
    if read_attribute(:value).blank? && encrypted? && !encrypted_was && value_was.present?
      write_attribute(:value, value_was)
    end

    raw = read_attribute(:value)
    return if raw.nil?
    # Пустое значение не храним как шифротекст пустоты (enc1:<пусто>): он
    # расшифровывается в "" и по правилу «пусто = не задано» молча выпадает из
    # инвентаря запуска, ломая шаблонизацию (например {{ansible_password}}).
    if raw.blank? && encrypted?
      write_attribute(:value, nil)
      return
    end
    if encrypted? && !VariableCipher.encrypted?(raw)
      write_attribute(:value, VariableCipher.encrypt(raw))
    elsif !encrypted? && VariableCipher.encrypted?(raw)
      write_attribute(:value, VariableCipher.decrypt(raw))
    end
  end
end
