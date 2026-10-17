# Ребрендинг домена «плейбук» -> «плей»: таблица playbooks -> plays,
# колонка runs.playbook_id -> play_id и полиморфные ссылки variables.
class RenamePlaybooksToPlays < ActiveRecord::Migration[7.0]
  def up
    remove_index :runs, name: "index_runs_on_playbook_id"
    rename_column :runs, :playbook_id, :play_id
    add_index :runs, :play_id, name: "index_runs_on_play_id"

    rename_table :playbooks, :plays

    # Полиморфный тип хранится строкой — обновляем данные.
    execute "UPDATE variables SET variableable_type = 'Play' WHERE variableable_type = 'Playbook'"
  end

  def down
    execute "UPDATE variables SET variableable_type = 'Playbook' WHERE variableable_type = 'Play'"

    rename_table :plays, :playbooks

    remove_index :runs, name: "index_runs_on_play_id"
    rename_column :runs, :play_id, :playbook_id
    add_index :runs, :playbook_id, name: "index_runs_on_playbook_id"
  end
end
