class CreateCommonVariables < ActiveRecord::Migration[7.0]
  def change
    create_table :common_variables do |t|
      t.string :name, null: false
      t.text :value
      t.timestamps
    end
    add_index :common_variables, :name, unique: true
  end
end
