class CreateVariables < ActiveRecord::Migration[7.0]
  def change
    create_table :variables do |t|
      t.string :name, null: false
      t.text :value
      t.references :variableable, polymorphic: true, null: false
      t.timestamps
    end
    add_index :variables, [:variableable_id, :variableable_type, :name], unique: true, name: "idx_variables_scope"
  end
end
