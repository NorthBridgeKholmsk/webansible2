class CreateZabbixOptions < ActiveRecord::Migration[7.0]
  def change
    create_table :zabbix_options do |t|
      t.string :category, null: false
      t.string :label, null: false
      t.string :value, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end
    add_index :zabbix_options, :category
  end
end
