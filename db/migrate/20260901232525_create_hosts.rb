class CreateHosts < ActiveRecord::Migration[7.0]
  def change
    create_table :hosts do |t|
      t.string :name, null: false
      t.string :ip, null: false
      t.string :login
      t.string :password
      t.string :type, null: false, default: "linux"   # тип хоста
      t.string :os_type, null: false, default: "ubuntu" # тип операционной системы
      t.string :role, null: false, default: "web"       # роль хоста
      t.references :organization, foreign_key: true
      t.timestamps
    end
    add_index :hosts, :ip, unique: true
  end
end
