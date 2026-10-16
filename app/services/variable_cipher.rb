# Шифрование значений переменных типа «зашифрованная» при хранении в БД.
#
# Формат: префикс + base64-шифротекст (AES-256-GCM, подпись включена).
# Строки без префикса читаются как есть — это обычные переменные и legacy-
# plaintext, сохранённый до введения шифрования.
class VariableCipher
  PREFIX = "enc1:"

  class << self
    def encrypted?(value)
      value.is_a?(String) && value.start_with?(PREFIX)
    end

    # Идемпотентно: уже зашифрованное значение не шифруется повторно.
    def encrypt(value)
      return value if value.nil? || encrypted?(value)
      PREFIX + encryptor.encrypt_and_sign(value.to_s)
    end

    # Строка без префикса возвращается как есть (обычная переменная).
    def decrypt(raw)
      return raw unless encrypted?(raw)
      encryptor.decrypt_and_verify(raw.delete_prefix(PREFIX))
    end

    private

    # Ключ: credentials -> ENV -> secret_key_base.
    # ВАЖНО: смена ключа делает ранее сохранённые шифротексты нечитаемыми —
    # ротация требует скрипта decrypt -> re-encrypt по всем строкам обеих таблиц.
    def key
      @key ||= begin
        raw = (credentials_key || ENV["VARIABLES_ENCRYPTION_KEY"] || Rails.application.secret_key_base).to_s
        raw.bytes.length >= 32 ? raw.byteslice(0, 32) : Digest::SHA256.digest(raw)
      end
    end

    # Если credentials недоступны/не расшифровываются в данном окружении —
    # не роняем приложение, а переходим к следующему источнику ключа.
    def credentials_key
      Rails.application.credentials[:variables_encryption_key]
    rescue StandardError
      nil
    end

    def encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
