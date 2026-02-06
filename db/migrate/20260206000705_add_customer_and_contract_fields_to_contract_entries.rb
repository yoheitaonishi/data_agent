class AddCustomerAndContractFieldsToContractEntries < ActiveRecord::Migration[8.1]
  def change
    # 基本情報ファイル（顧客情報）用のカラム
    # 申込者（契約者）情報
    add_column :contract_entries, :applicant_name_kana, :string  # 申込者氏名（カタカナ）
    add_column :contract_entries, :applicant_birth_date, :date  # 生年月日
    add_column :contract_entries, :applicant_gender, :integer  # 性別（0:男, 1:女, 2:その他）
    add_column :contract_entries, :applicant_is_corporate, :boolean, default: false  # 法人区分

    # 連絡先情報1（物件住所）
    add_column :contract_entries, :contact1_postal_code, :string  # 連絡先郵便番号1
    add_column :contract_entries, :contact1_address1, :string  # 連絡先住所1_1
    add_column :contract_entries, :contact1_address2, :string  # 連絡先住所1_2
    add_column :contract_entries, :contact1_phone1, :string  # 連絡先電話番号1（携帯）
    add_column :contract_entries, :contact1_email, :string  # 連絡先メールアドレス1

    # 連絡先情報2（入居者2）
    add_column :contract_entries, :contact2_name, :string  # 連絡先名2（入居者2氏名）
    add_column :contract_entries, :contact2_postal_code, :string  # 連絡先郵便番号2
    add_column :contract_entries, :contact2_address1, :string  # 連絡先住所2_1
    add_column :contract_entries, :contact2_address2, :string  # 連絡先住所2_2
    add_column :contract_entries, :contact2_phone1, :string  # 連絡先電話番号2（携帯）
    add_column :contract_entries, :contact2_email, :string  # 連絡先メールアドレス2

    # 勤務先情報
    add_column :contract_entries, :workplace_name, :string  # 勤務先名
    add_column :contract_entries, :workplace_department, :string  # 所属部署
    add_column :contract_entries, :workplace_position, :string  # 役職
    add_column :contract_entries, :workplace_postal_code, :string  # 勤務先郵便番号
    add_column :contract_entries, :workplace_address, :string  # 勤務先住所
    add_column :contract_entries, :workplace_phone, :string  # 勤務先電話番号

    # 緊急連絡先情報
    add_column :contract_entries, :emergency_contact_name, :string  # 緊急連絡先氏名
    add_column :contract_entries, :emergency_contact_postal_code, :string  # 緊急連絡先郵便番号
    add_column :contract_entries, :emergency_contact_address, :string  # 緊急連絡先住所
    add_column :contract_entries, :emergency_contact_phone, :string  # 緊急連絡先電話番号
    add_column :contract_entries, :emergency_contact_relationship, :string  # 緊急連絡先続柄

    # 契約ファイル用のカラム
    add_column :contract_entries, :property_code, :string  # 物件コード
    add_column :contract_entries, :contract_code, :string  # 受入元契約番号
    add_column :contract_entries, :customer_code, :string  # 契約者コード
    add_column :contract_entries, :move_in_date, :date  # 入居日
    add_column :contract_entries, :contract_start_date, :date  # 契約開始日
    add_column :contract_entries, :contract_complete_date, :date  # 契約完了日
    add_column :contract_entries, :contract_date, :date  # 契約日
    add_column :contract_entries, :contract_end_date, :date  # 満了日
    add_column :contract_entries, :initial_contract_date, :date  # 初回契約日
    add_column :contract_entries, :revenue_recording_date, :date  # 売上計上日
    add_column :contract_entries, :rent_start_date, :date  # 賃料発生日
    add_column :contract_entries, :monthly_tax_base_date, :date  # 月額消費税基準日
    add_column :contract_entries, :result_aggregation_month, :string  # 実績集計年月

    add_column :contract_entries, :daily_rent_days, :integer  # 日割日数
    add_column :contract_entries, :monthly_billing_months, :integer  # 翌月以降請求月数
    add_column :contract_entries, :renewal_period_years, :integer  # 更新期間(年)
    add_column :contract_entries, :renewal_period_months, :integer  # 更新期間(月)

    add_column :contract_entries, :billing_collection_month, :integer  # 回収月区分
    add_column :contract_entries, :payment_due_date, :integer  # 入金期日
    add_column :contract_entries, :holiday_processing, :integer  # 休日処理区分

    add_column :contract_entries, :applicant_deposit_amount, :decimal, precision: 10, scale: 2  # 契約者申込金額

    add_column :contract_entries, :contract_staff_code, :string  # 契約担当者コード
    add_column :contract_entries, :unpaid_recording_date, :date  # 未払計上日
    add_column :contract_entries, :payment_scheduled_date, :date  # 支払予定日

    # インデックスを追加
    add_index :contract_entries, :applicant_name_kana
    add_index :contract_entries, :applicant_birth_date
    add_index :contract_entries, :property_code
    add_index :contract_entries, :contract_code
    add_index :contract_entries, :customer_code
    add_index :contract_entries, :move_in_date
    add_index :contract_entries, :contract_start_date
  end
end
