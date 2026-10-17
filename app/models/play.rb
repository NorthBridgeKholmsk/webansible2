# Плей Ansible (YAML-содержимое хранится в БД).
#
# При запуске содержимое пишется во временный файл и исполняется
# ansible-playbook (см. RunLauncher). os_type — тип ОС, для которого
# предназначен плей.
class Play < ApplicationRecord
  # Переменные уровня плея (имя/значение), доступные при его запуске.
  has_many :variables, as: :variableable, dependent: :destroy

  validates :name, presence: true
  validates :os_type, presence: true

  scope :for_os, ->(os) { where(os_type: os) }

  # Содержимое как строка (защита от NULL в старых записях).
  def content
    super.to_s
  end
end
