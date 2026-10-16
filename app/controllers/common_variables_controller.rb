# Общие переменные — плоский список пар имя/значение для всех хостов.
# Сохранение пакетное (как у списков настроек): items[][id|name|value].
# Строки без id создаются, с id обновляются; записи, отсутствующие в форме, удаляются.
class CommonVariablesController < ApplicationController
  def index
    @common_variables = CommonVariable.order(:name)
    content_for(:page_title) { "Общие переменные" }
  end

  def update
    items = normalize_items(params[:items])

    kept_ids = []
    seen_names = {}
    items.each do |it|
      name = it["name"].to_s.strip
      # Пустые имена и дубликаты в рамках одной формы игнорируем:
      # существующая запись с таким id просто не попадёт в kept_ids.
      next if name.blank? || seen_names[name]
      seen_names[name] = true

      value = it["value"].to_s
      encrypted = it["encrypted"] == "1" || it["encrypted"] == true
      id = it["id"].presence
      if (variable = CommonVariable.find_by(id: id))
        variable.update(name: name, value: value, encrypted: encrypted)
        kept_ids << variable.id
      else
        created = CommonVariable.create(name: name, value: value, encrypted: encrypted)
        kept_ids << created.id if created
      end
    end

    if kept_ids.any?
      CommonVariable.where.not(id: kept_ids).delete_all
    else
      CommonVariable.delete_all
    end

    redirect_to common_variables_path, notice: "Общие переменные сохранены"
  end

  private

  # Форма шлёт items[] как массив хешей. Пустая форма может не передать ключ
  # вовсе (или, при сериализации пустого массива, строку "") — приводим всё
  # к массиву хешей с текстовыми ключами.
  def normalize_items(raw)
    Array(raw).flatten.compact.map do |it|
      it.is_a?(ActionController::Parameters) ? it.to_unsafe_h : {}
    end
  end
end
