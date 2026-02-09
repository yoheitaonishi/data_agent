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

ActiveRecord::Schema[8.1].define(version: 2026_02_09_091447) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agentic_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "action_required"
    t.datetime "created_at", null: false
    t.string "destination_system"
    t.text "error_message"
    t.datetime "executed_at"
    t.integer "record_count"
    t.string "source_system"
    t.string "status"
    t.integer "step"
    t.datetime "updated_at", null: false
  end

  create_table "contract_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "additional_data"
    t.string "address"
    t.integer "agentic_job_id"
    t.date "applicant_birth_date"
    t.decimal "applicant_deposit_amount", precision: 10, scale: 2
    t.string "applicant_edit_permission"
    t.string "applicant_email"
    t.integer "applicant_gender"
    t.boolean "applicant_is_corporate", default: false
    t.string "applicant_name"
    t.string "applicant_name_kana"
    t.string "applicant_type"
    t.datetime "application_date"
    t.string "application_method"
    t.decimal "area", precision: 10, scale: 2
    t.integer "billing_collection_month"
    t.string "broker_company_name"
    t.string "broker_phone"
    t.string "broker_staff_email"
    t.string "broker_staff_name"
    t.string "broker_staff_phone"
    t.string "contact1_address1"
    t.string "contact1_address2"
    t.string "contact1_email"
    t.string "contact1_phone1"
    t.string "contact1_postal_code"
    t.string "contact2_address1"
    t.string "contact2_address2"
    t.string "contact2_email"
    t.string "contact2_name"
    t.string "contact2_phone1"
    t.string "contact2_postal_code"
    t.string "contract_code"
    t.date "contract_complete_date"
    t.date "contract_date"
    t.date "contract_end_date"
    t.string "contract_method"
    t.string "contract_staff_code"
    t.date "contract_start_date"
    t.datetime "created_at", null: false
    t.string "customer_code"
    t.integer "daily_rent_days"
    t.decimal "deposit", precision: 10, scale: 2
    t.string "detail_url"
    t.string "emergency_contact_address"
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "emergency_contact_postal_code"
    t.string "emergency_contact_relationship"
    t.string "entry_head_id"
    t.string "entry_status"
    t.string "guarantee_company"
    t.decimal "guarantee_deposit", precision: 10, scale: 2
    t.string "guarantee_result"
    t.integer "holiday_processing"
    t.date "initial_contract_date"
    t.string "joint_guarantor_usage"
    t.decimal "key_money", precision: 10, scale: 2
    t.decimal "management_fee", precision: 10, scale: 2
    t.integer "monthly_billing_months"
    t.date "monthly_tax_base_date"
    t.date "move_in_date"
    t.integer "payment_due_date"
    t.date "payment_scheduled_date"
    t.integer "priority"
    t.string "property_code"
    t.string "property_name"
    t.string "registration_number"
    t.integer "renewal_period_months"
    t.integer "renewal_period_years"
    t.decimal "rent", precision: 10, scale: 2
    t.date "rent_start_date"
    t.string "result_aggregation_month"
    t.date "revenue_recording_date"
    t.string "room_id"
    t.date "unpaid_recording_date"
    t.datetime "updated_at", null: false
    t.string "workplace_address"
    t.string "workplace_department"
    t.string "workplace_name"
    t.string "workplace_phone"
    t.string "workplace_position"
    t.string "workplace_postal_code"
    t.index ["agentic_job_id"], name: "index_contract_entries_on_agentic_job_id"
    t.index ["applicant_birth_date"], name: "index_contract_entries_on_applicant_birth_date"
    t.index ["applicant_name"], name: "index_contract_entries_on_applicant_name"
    t.index ["applicant_name_kana"], name: "index_contract_entries_on_applicant_name_kana"
    t.index ["application_date"], name: "index_contract_entries_on_application_date"
    t.index ["contract_code"], name: "index_contract_entries_on_contract_code"
    t.index ["contract_start_date"], name: "index_contract_entries_on_contract_start_date"
    t.index ["customer_code"], name: "index_contract_entries_on_customer_code"
    t.index ["entry_head_id"], name: "index_contract_entries_on_entry_head_id"
    t.index ["guarantee_company"], name: "index_contract_entries_on_guarantee_company"
    t.index ["move_in_date"], name: "index_contract_entries_on_move_in_date"
    t.index ["property_code"], name: "index_contract_entries_on_property_code"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
