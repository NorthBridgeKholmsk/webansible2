# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_10_17_000000) do
  create_table "common_variables", force: :cascade do |t|
    t.string "name", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "encrypted", default: false, null: false
    t.index ["name"], name: "index_common_variables_on_name", unique: true
  end

  create_table "files", force: :cascade do |t|
    t.string "name", null: false
    t.string "path"
    t.integer "organization_id"
    t.text "content"
    t.string "mime_type", default: "application/octet-stream"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_files_on_organization_id"
  end

  create_table "hosts", force: :cascade do |t|
    t.string "name", null: false
    t.string "ip", null: false
    t.string "login"
    t.string "password"
    t.string "type", default: "Host", null: false
    t.string "os_type", default: "ubuntu", null: false
    t.string "role", default: "web", null: false
    t.integer "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "manual", null: false
    t.index ["ip"], name: "index_hosts_on_ip", unique: true
    t.index ["organization_id"], name: "index_hosts_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "manual", null: false
  end

  create_table "plays", force: :cascade do |t|
    t.string "name", null: false
    t.string "os_type", default: "ubuntu", null: false
    t.text "content"
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "runs", force: :cascade do |t|
    t.integer "play_id", null: false
    t.integer "user_id"
    t.string "status", default: "pending", null: false
    t.integer "exit_code"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text "hosts_snapshot"
    t.text "variables"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["play_id"], name: "index_runs_on_play_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "login", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  create_table "variables", force: :cascade do |t|
    t.string "name", null: false
    t.text "value"
    t.string "variableable_type", null: false
    t.integer "variableable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "encrypted", default: false, null: false
    t.index ["variableable_id", "variableable_type", "name"], name: "idx_variables_scope", unique: true
    t.index ["variableable_type", "variableable_id"], name: "index_variables_on_variableable"
  end

  create_table "zabbix_options", force: :cascade do |t|
    t.string "category", null: false
    t.string "label", null: false
    t.string "value", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_zabbix_options_on_category"
  end

  add_foreign_key "files", "organizations"
  add_foreign_key "hosts", "organizations"
end
