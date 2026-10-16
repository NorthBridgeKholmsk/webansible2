class RemoveTypeAndOrganizationFromPlaybooks < ActiveRecord::Migration[7.0]
  def change
    remove_column :playbooks, :playbook_type, :string
    remove_column :playbooks, :organization_id, :integer
  end
end
