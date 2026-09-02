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

ActiveRecord::Schema[8.1].define(version: 2026_09_02_210943) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "fields", force: :cascade do |t|
    t.string "choices", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "form_id", null: false
    t.integer "input_type", null: false
    t.string "label", null: false
    t.integer "position", null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "value_type", null: false
    t.index ["form_id", "position"], name: "index_fields_on_form_id_and_position", unique: true
    t.index ["form_id"], name: "index_fields_on_form_id"
  end

  create_table "forms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "created_at"], name: "index_forms_on_owner_id_and_created_at"
    t.index ["owner_id"], name: "index_forms_on_owner_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "form_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "values", default: {}, null: false
    t.index ["form_id", "user_id"], name: "index_submissions_on_form_id_and_user_id", unique: true
    t.index ["form_id"], name: "index_submissions_on_form_id"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "fields", "forms", name: "fk_fields_form_id"
  add_foreign_key "forms", "users", column: "owner_id", name: "fk_forms_owner_id"
  add_foreign_key "submissions", "forms", name: "fk_submissions_form_id"
  add_foreign_key "submissions", "users", name: "fk_submissions_user_id"
end
