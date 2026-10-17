# Плейбук — конструктор из плеев: набор ветвлений (секций) по типу ОС,
# внутри каждой секции упорядоченный список плеев, выполняемых по порядку.
class Playbook < ApplicationRecord
  has_many :sections, -> { order(:id) }, class_name: "PlaybookSection", dependent: :destroy

  accepts_nested_attributes_for :sections, allow_destroy: true

  validates :name, presence: true

  # ОС ветвлений, в которые добавлены плеи (для списка плейбуков).
  def os_types_with_plays
    sections.joins(:section_plays).distinct.order(:id).pluck(:os_type)
  end
end