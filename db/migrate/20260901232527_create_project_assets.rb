class CreateProjectAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :files do |t|
      t.string :name, null: false
      t.string :path
      t.references :organization, foreign_key: true
      t.text :content
      t.string :mime_type, default: "application/octet-stream"
      t.timestamps
    end

    create_table :playbooks do |t|
      t.string :name, null: false
      t.string :os_type, null: false, default: "ubuntu"
      t.string :playbook_type, null: false, default: "deploy"
      t.references :organization, foreign_key: true
      t.text :content
      t.text :description
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
  end
end
