class CreateRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :runs do |t|
      t.references :playbook, null: false
      t.integer :user_id
      t.string :status, default: "pending", null: false
      t.integer :exit_code
      t.datetime :started_at
      t.datetime :finished_at
      # Снимок хостов на момент запуска (JSON-массив {name, ip}).
      t.text :hosts_snapshot
      # Эффективные переменные (JSON): {"form" => {...}, "hosts" => {имя_хоста => {...}}}.
      t.text :variables

      t.timestamps
    end
  end
end
