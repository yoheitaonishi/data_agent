class CreateContractEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :contract_entries do |t|
      # 基本情報
      t.string :entry_head_id
      t.string :property_name
      t.string :detail_url

      # 物件情報
      t.string :room_id
      t.string :address
      t.decimal :area, precision: 10, scale: 2
      t.decimal :rent, precision: 10, scale: 2
      t.decimal :management_fee, precision: 10, scale: 2
      t.decimal :deposit, precision: 10, scale: 2
      t.decimal :key_money, precision: 10, scale: 2
      t.decimal :guarantee_deposit, precision: 10, scale: 2

      # 申込者情報
      t.string :applicant_name
      t.datetime :application_date
      t.integer :priority
      t.string :applicant_email
      t.string :entry_status

      # 仲介会社情報
      t.string :broker_company_name
      t.string :broker_phone
      t.string :broker_staff_name
      t.string :broker_staff_phone
      t.string :broker_staff_email

      # その他のフィールド（拡張用）
      t.text :additional_data

      t.timestamps
    end

    add_index :contract_entries, :entry_head_id
    add_index :contract_entries, :applicant_name
    add_index :contract_entries, :application_date
  end
end
