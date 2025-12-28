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

ActiveRecord::Schema[8.1].define(version: 2025_12_28_091918) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "users", force: :cascade do |t|
    t.integer "auth_attempts_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "eth_address", null: false
    t.string "eth_nonce", null: false
    t.datetime "last_auth_attempt_at"
    t.datetime "nonce_issued_at"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["eth_address"], name: "index_users_on_eth_address", unique: true
    t.index ["eth_nonce"], name: "index_users_on_eth_nonce", unique: true
    t.index ["last_auth_attempt_at"], name: "index_users_on_last_auth_attempt_at"
    t.index ["nonce_issued_at"], name: "index_users_on_nonce_issued_at"
    t.index ["verified"], name: "index_users_on_verified"
  end
end
