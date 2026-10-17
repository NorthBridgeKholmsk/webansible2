# Плейбуки — конструктор из плеев с ветвлением по типу ОС.
# playbook_sections — ветвления (секции) плейбука; порядок секций = порядок создания.
# playbook_section_plays — упорядоченный список плеев внутри ветвления (position).
class CreatePlaybooks < ActiveRecord::Migration[7.0]
  def change
    create_table :playbooks do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :playbook_sections do |t|
      t.references :playbook, null: false
      t.string :os_type, null: false
      t.timestamps
    end

    create_table :playbook_section_plays do |t|
      t.references :playbook_section, null: false
      t.references :play, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :playbook_sections, :playbooks
    add_foreign_key :playbook_section_plays, :playbook_sections
    add_foreign_key :playbook_section_plays, :plays
  end
end