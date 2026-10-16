# Добавляет тип переменной: обычная (plaintext) или зашифрованная.
# Существующие строки остаются обычными — бэкапфилл не требуется.
class AddEncryptedToVariables < ActiveRecord::Migration[7.0]
  def change
    add_column :variables, :encrypted, :boolean, default: false, null: false
    add_column :common_variables, :encrypted, :boolean, default: false, null: false
  end
end
