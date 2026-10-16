# Хранит пункты списков «Типы хостов», «Роли хостов» и «Типы ОС».
# category — к какой из трёх списков относится запись:
#   "type"  — тип хоста  (значение — группа Zabbix);
#   "role"  — роль хоста  (значение — перечень имён хостов в Zabbix);
#   "os_type" — тип ОС     (значение — группа Zabbix).
# enabled — флаг «отображать в выпадающем списке».
class ZabbixOption < ApplicationRecord
  CATEGORIES = %w[type role os_type].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :label, presence: true
  validates :value, presence: true

  scope :by_category, ->(category) { where(category: category) }

  def self.options_for(category)
    # [{ label:, value: }] — для options_for_select: текст = label (отображаемое имя),
    # значение = value (группа Zabbix, для ролей — перечень имён хостов Zabbix).
    # В выпадающем списке показываются только отмеченные чекбоксом (enabled) пункты.
    by_category(category).where(enabled: true).order(:label).pluck(:label, :value)
  end
end
