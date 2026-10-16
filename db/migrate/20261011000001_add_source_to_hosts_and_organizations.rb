# Поле «Источник» (нередактируемое из UI): откуда запись.
#   "manual" — создана вручную из UI;
#   "zabbix" — создана синхронизацией с Zabbix.
# Устанавливается только при создании; дефолт "manual", т.к. обычный путь
# создания из контроллеров не передаёт это поле (оно не в permit).
class AddSourceToHostsAndOrganizations < ActiveRecord::Migration[7.0]
  def change
    add_column :hosts, :source, :string, default: "manual", null: false
    add_column :organizations, :source, :string, default: "manual", null: false
  end
end
