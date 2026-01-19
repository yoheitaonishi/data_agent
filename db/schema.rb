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

ActiveRecord::Schema[8.1].define(version: 2026_01_19_075337) do
  create_table "agentic_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "action_required"
    t.datetime "created_at", null: false
    t.string "destination_system"
    t.text "error_message"
    t.datetime "executed_at"
    t.integer "record_count"
    t.string "source_system"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "contract_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "additional_data"
    t.string "address"
    t.string "applicant_edit_permission"
    t.string "applicant_email"
    t.string "applicant_name"
    t.datetime "application_date"
    t.string "application_method"
    t.decimal "area", precision: 10, scale: 2
    t.decimal "balcony_area", precision: 10, scale: 2
    t.string "broker_company_name"
    t.string "broker_phone"
    t.string "broker_staff_email"
    t.string "broker_staff_name"
    t.string "broker_staff_phone"
    t.string "building_structure"
    t.string "contract_method"
    t.string "contract_period"
    t.date "contract_start_date"
    t.datetime "created_at", null: false
    t.decimal "deposit", precision: 10, scale: 2
    t.string "detail_url"
    t.string "entry_head_id"
    t.string "entry_status"
    t.string "floor"
    t.string "guarantee_company"
    t.decimal "guarantee_deposit", precision: 10, scale: 2
    t.string "guarantee_result"
    t.string "joint_guarantor_usage"
    t.decimal "key_money", precision: 10, scale: 2
    t.decimal "management_fee", precision: 10, scale: 2
    t.date "move_in_date"
    t.text "other_fees"
    t.decimal "parking_fee", precision: 10, scale: 2
    t.integer "priority"
    t.string "property_name"
    t.string "registration_number"
    t.decimal "renewal_fee", precision: 10, scale: 2
    t.decimal "rent", precision: 10, scale: 2
    t.string "room_id"
    t.string "room_status"
    t.datetime "updated_at", null: false
    t.index ["applicant_name"], name: "index_contract_entries_on_applicant_name"
    t.index ["application_date"], name: "index_contract_entries_on_application_date"
    t.index ["contract_start_date"], name: "index_contract_entries_on_contract_start_date"
    t.index ["entry_head_id"], name: "index_contract_entries_on_entry_head_id"
    t.index ["guarantee_company"], name: "index_contract_entries_on_guarantee_company"
    t.index ["move_in_date"], name: "index_contract_entries_on_move_in_date"
  end
end
