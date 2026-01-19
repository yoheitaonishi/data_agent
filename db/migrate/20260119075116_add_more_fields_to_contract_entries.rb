class AddMoreFieldsToContractEntries < ActiveRecord::Migration[8.1]
  def change
    # 適格請求書関連
    add_column :contract_entries, :qualified_invoice_issuer, :string
    add_column :contract_entries, :registration_number, :string

    # 保証会社関連
    add_column :contract_entries, :guarantee_company, :string
    add_column :contract_entries, :guarantee_result, :string

    # 連帯保証人関連
    add_column :contract_entries, :joint_guarantor_usage, :string

    # 契約方法
    add_column :contract_entries, :contract_method, :string

    # 申込者編集権限
    add_column :contract_entries, :applicant_edit_permission, :string

    # 部屋ステータス
    add_column :contract_entries, :room_status, :string

    # その他詳細情報（必要に応じて追加）
    add_column :contract_entries, :building_structure, :string
    add_column :contract_entries, :floor, :string
    add_column :contract_entries, :balcony_area, :decimal, precision: 10, scale: 2
    add_column :contract_entries, :parking_fee, :decimal, precision: 10, scale: 2
    add_column :contract_entries, :other_fees, :text

    # 契約日関連
    add_column :contract_entries, :contract_start_date, :date
    add_column :contract_entries, :move_in_date, :date
    add_column :contract_entries, :contract_period, :string

    # 更新料
    add_column :contract_entries, :renewal_fee, :decimal, precision: 10, scale: 2

    # 申込方法
    add_column :contract_entries, :application_method, :string

    # インデックス追加
    add_index :contract_entries, :contract_start_date
    add_index :contract_entries, :move_in_date
    add_index :contract_entries, :guarantee_company
  end
end
