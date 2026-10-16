require "active_support/message_encryptor"

module Zabbix
  # Настройки подключения к Zabbix: адрес (plain) и API-ключ (зашифрован в БД).
  # Хранятся в таблице settings (key/value), как и остальные глобальные настройки.
  module Settings
    URL_KEY = "zabbix_url"
    API_KEY_KEY = "zabbix_api_key"
    INSECURE_SSL_KEY = "zabbix_insecure_ssl"

    # Шифрование API-ключа средствами Rails (aes-256-cbc + padding).
    # Ключ для шифрования_derive_ из secret_key_base, чтобы не требовать отдельной настройки.
    class Cipher
      KEY = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key("zabbix/api-key", 32)

      def self.encrypt(plaintext)
        ActiveSupport::MessageEncryptor.new(KEY).encrypt_and_sign(plaintext.to_s)
      end

      def self.decrypt(ciphertext)
        return nil if ciphertext.blank?
        ActiveSupport::MessageEncryptor.new(KEY).decrypt_and_verify(ciphertext)
      rescue StandardError
        nil
      end
    end

    class << self
      def url
        Setting.find_by(key: URL_KEY)&.value
      end

      def api_key
        record = Setting.find_by(key: API_KEY_KEY)
        return nil if record.blank? || record.value.blank?
        Cipher.decrypt(record.value)
      end

      def configured?
        url.present? && api_key.present?
      end

      # Не проверять TLS-сертификат Zabbix (self-signed). Хранится как "1"/"0".
      def insecure_ssl?
        %w[1 true].include?(Setting.find_by(key: INSECURE_SSL_KEY)&.value)
      end

      # URL сохраняется как есть. Если передан новый ключ — шифруем и сохраняем,
      # иначе старый ключ не трогаем (чтобы пустое поле в форме его не очищило).
      # insecure_ssl: true/false — состояние чекбокса; nil — не менять.
      def apply(url:, api_key:, insecure_ssl: nil)
        url = url.to_s.strip.presence
        if url
          Setting.find_or_initialize_by(key: URL_KEY).tap { |s| s.value = url }.save!(validate: false)
        end

        unless api_key.to_s.blank?
          encrypted = Cipher.encrypt(api_key)
          Setting.find_or_initialize_by(key: API_KEY_KEY).tap { |s| s.value = encrypted }.save!(validate: false)
        end

        if !insecure_ssl.nil?
          Setting.find_or_initialize_by(key: INSECURE_SSL_KEY).tap { |s| s.value = insecure_ssl ? "1" : "0" }.save!(validate: false)
        end
      end

      def reset!
        Setting.where(key: [URL_KEY, API_KEY_KEY, INSECURE_SSL_KEY]).delete_all
      end
    end
  end
end