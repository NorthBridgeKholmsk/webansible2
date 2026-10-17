# Связь «ветвление плейбука → плей» с порядком выполнения (position).
class PlaybookSectionPlay < ApplicationRecord
  belongs_to :playbook_section
  belongs_to :play
end