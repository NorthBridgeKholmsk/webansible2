# Файл проекта (документ/ассет), привязанный к организации.
#
# Таблица намеренно называется files, а модель — FileEntry,
# чтобы не конфликтовать с Ruby::File.
class FileEntry < ApplicationRecord
  self.table_name = "files"

  belongs_to :organization

  validates :name, presence: true

  # Имя файла для скачивания: последняя часть пути (без каталогов).
  def download_filename
    name.to_s.split("/").last || name
  end
end
