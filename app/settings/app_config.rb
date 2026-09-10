module Settings
  # Lightweight settings store. Values are kept in-memory and can be
  # persisted later (e.g. to a database or YAML file).
  class AppConfig
    DEFAULTS = {
      "app_name" => "WebAnsible",
      "ansible_path" => "/usr/bin/ansible",
      "ansible_playbook_path" => "/usr/bin/ansible-playbook",
      "default_timeout" => "300",
      "default_user" => "root",
      "theme" => "light"
    }.freeze

    # Ключи, которые храним в БД. Порядок фиксируем, чтобы
    # `to_h` и запись в БД были детерминированными.
    CACHED_KEYS = DEFAULTS.keys.freeze

    # Общие «в памяти» значения для всех инстанций класса.
    # При первом обращении данные подгружаются из БД (`settings`);
    # если таблица пустая — используются DEFAULTS. `apply` сохраняет
    # изменения и в память, и в БД, поэтому новые значения видны сразу.
    def self.data
      @data ||= load_from_db
    end

    def self.load_from_db
      return DEFAULTS.dup if Setting.count.zero?

      values = Setting.pluck(:key, :value).to_h
      DEFAULTS.each_key { |key| values[key] = DEFAULTS[key] if values[key].blank? }
      values
    end

    # Upsert всех ключей в таблице `settings`.
    def self.persist!
      CACHED_KEYS.each do |key|
        setting = Setting.find_or_initialize_by(key: key)
        setting.value = data[key]
        setting.save!(validate: false)
      end
    end

    def initialize(data = {})
      self.class.data.merge!(data.stringify_keys) unless data.empty?
    end

    def [](key)
      self.class.data[key.to_s]
    end

    def to_h
      self.class.data.dup
    end

    def apply(params)
      CACHED_KEYS.each do |key|
        value = params[key.to_s]
        self.class.data[key.to_s] = value if value.present?
      end
      self.class.persist!
      self
    end
  end
end