# Ветвление плейбука по типу ОС (секция конструктора).
class PlaybookSection < ApplicationRecord
  belongs_to :playbook
  has_many :section_plays, -> { order(:position, :id) }, class_name: "PlaybookSectionPlay", dependent: :destroy
  has_many :plays, through: :section_plays

  accepts_nested_attributes_for :section_plays, allow_destroy: true

  validates :os_type, presence: true
end