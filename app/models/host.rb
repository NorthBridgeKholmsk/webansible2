class Host < ApplicationRecord
  # Источник записи (нередактируемое из UI): устанавливается только при создании.
  SOURCE_MANUAL = "manual" # создана вручную из UI
  SOURCE_ZABBIX = "zabbix" # создана синхронизацией с Zabbix

  SOURCES = [SOURCE_MANUAL, SOURCE_ZABBIX].freeze

  belongs_to :organization

  has_many :variables, as: :variableable, dependent: :destroy

  # Вложенные атрибуты переменных из формы хоста (host[variables_attributes][...]).
  # allow_destroy — чтобы работал _destroy из формы (кнопка «Удалить»).
  # reject_if — не создавать пустые записи (без имени переменной).
  accepts_nested_attributes_for :variables,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:name].blank? }

  validates :name, presence: true
  validates :ip, presence: true

  # type — тип хоста (например, linux, windows, network);
  # os_type — тип ОС (ubuntu, debian, windows…);
  # role — роль(и) хоста (web, db, cache…) — массив значений.
  validates :type, presence: true
  validates :os_type, presence: true
  validates :role, presence: true
  validates :source, inclusion: { in: SOURCES }

  # Хосты, созданные синхронизацией с Zabbix (для удаления устаревших при синке).
  scope :from_zabbix, -> { where(source: SOURCE_ZABBIX) }

  # Человекочитаемый источник для UI.
  def source_label
    self.source == SOURCE_ZABBIX ? "Zabbix" : "Вручную"
  end

  # Поиск по списку хостов (index): частичное совпадение по имени или IP-адресу.
  scope :search_by_name_or_ip, lambda { |q|
    pattern = "%#{sanitize_sql_like(q)}%"
    where("hosts.name LIKE :pattern OR hosts.ip LIKE :pattern", pattern: pattern)
  }

  # Роль хранится в строковом столбце как JSON-массив значений, поэтому поиск —
  # по подстроке. Работает и для новых записей (["web"]), и для устаревших
  # одиночных строк ("web").
  scope :search_by_role, ->(role) { where("hosts.role LIKE ?", "%#{sanitize_sql_like(role)}%") }

  # Роль хоста — массив значений (мультивыбор из списка ZabbixOption).
  # Хранится в строковом столбце в виде JSON-массива.
  # Для новых записей по умолчанию пустой массив.
  serialize :role, coder: JSON, default: []

  # Столбец «type» участвует в STI, но в нём хранится свободное значение
  # (тип хоста из выпадающего списка), а не имя подкласса, поэтому
  # разрешение класса всегда должно сводиться к Host.
  # В Rails 7.0 резолвинг может идти через sti_class_for или _compute_type,
  # и в обоих случаях ловим SubclassNotFound/NameError и возвращаем self.
  def self.sti_class_for(type_name)
    super
  rescue ActiveRecord::SubclassNotFound, NameError
    self
  end

  def self._compute_type(type_name)
    super
  rescue ActiveRecord::SubclassNotFound, NameError
    self
  end

  # Точка №3 (для надёжности): find_sti_class — то, что вызывает
  # discriminate_class_for_record при загрузке записи. Для свободного
  # «type» без реальных подклассов всегда возвращаем Host.
  def self.find_sti_class(type_name)
    self
  end

  # Роль как массив — для select[multiple] и отображения.
  # Учитывает как новые записи (JSON-массив), так и устаревшие
  # строковые роли (одиночное значение приводится к одиночному элементу).
  def role_array
    case role
    when Array then role.uniq
    when String then [role]
    else []
    end
  end
end
