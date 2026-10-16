# The `type` column (STI discriminator) defaulted to "linux", which is not a
# valid constant, so `Host.new` failed with ActiveRecord::SubclassNotFound.
# Change the default to "Host" (the base class) and normalise existing rows.
class FixHostsTypeDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :hosts, :type, from: "linux", to: "Host"
    Host.where.not(type: "Host").update_all(type: "Host")
  end
end
