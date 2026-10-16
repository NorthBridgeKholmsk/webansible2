class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :login, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "admin"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :users, :login, unique: true
  end
end
