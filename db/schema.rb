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

ActiveRecord::Schema[8.0].define(version: 2025_11_21_120000) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "episodes", force: :cascade do |t|
    t.string "title", null: false
    t.integer "season_number"
    t.integer "episode_number"
    t.text "description"
    t.date "aired_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "show_id", null: false
    t.text "alternate_titles"
    t.bigint "tvdb_id"
    t.index ["show_id"], name: "index_episodes_on_show_id"
    t.index ["title"], name: "index_episodes_on_show_name_and_title"
    t.index ["tvdb_id"], name: "index_episodes_on_tvdb_id", unique: true
  end

  create_table "shows", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tvdb_id"
    t.index ["name"], name: "index_shows_on_name", unique: true
    t.index ["tvdb_id"], name: "index_shows_on_tvdb_id", unique: true
  end

  add_foreign_key "episodes", "shows"
end
