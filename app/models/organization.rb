class Organization < ApplicationRecord
  # Источник записи (нередактируемое из UI): устанавливается только при создании.
  SOURCE_MANUAL = "manual" # создана вручную из UI
  SOURCE_ZABBIX = "zabbix" # создана синхронизацией с Zabbix

  SOURCES = [SOURCE_MANUAL, SOURCE_ZABBIX].freeze

  # При удалении организации удаляются все её хосты (и их переменные каскадом).
  has_many :hosts, class_name: "Host", dependent: :destroy
  has_many :files, class_name: "FileEntry", dependent: :destroy

  # Переменные организации (имя/значение) — полиморфная связь.
  has_many :variables, as: :variableable, dependent: :destroy

  # Вложенные атрибуты переменных из формы организации (org[variables_attributes][...]).
  # allow_destroy — чтобы работал _destroy из формы. reject_if — не создавать пустые записи.
  accepts_nested_attributes_for :variables,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:name].blank? }

  validates :name, presence: true, uniqueness: true
  validates :source, inclusion: { in: SOURCES }

  # Организации, созданные синхронизацией с Zabbix (для удаления пустых при синке).
  scope :from_zabbix, -> { where(source: SOURCE_ZABBIX) }

  # Человекочитаемый источник для UI.
  def source_label
    self.source == SOURCE_ZABBIX ? "Zabbix" : "Вручную"
  end

  # Пустая организация — нет ни хостов, ни файлов, ни переменных.
  # Используется синхронизацией: zabbix-организацию удаляем только если в ней
  # не осталось пользовательских данных (иначе снесём файлы/переменные).
  def empty?
    hosts.none? && files.none? && variables.none?
  end

  # Поиск по списку организаций (index): частичное совпадение по имени.
  scope :search_by_name, ->(q) { where("organizations.name LIKE ?", "%#{sanitize_sql_like(q)}%") }

  def host_count
    hosts.count
  end
end
