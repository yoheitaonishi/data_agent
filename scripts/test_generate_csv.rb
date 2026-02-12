#!/usr/bin/env ruby
# テスト用スクリプト: OBIC7にアクセスせずにローカルのマスターCSVを使用してcustomerとcontractsのCSVを生成

require_relative 'config/environment'

# テスト用のAgenticJobとContractEntryを作成
def create_test_data
  puts "Creating test AgenticJob and ContractEntries..."

  # テスト用のAgenticJobを作成
  job = AgenticJob.create!(
    source_system: "イタンジ",
    destination_system: "OBIC7",
    status: "processing",
    executed_at: Time.current,
    action_required: false
  )

  # テスト用のContractEntryを作成
  test_entries = [
    {
      entry_head_id: "TEST001",
      property_name: "ル･リオン練馬富士見台 101",
      applicant_name: "山田 太郎",
      applicant_name_kana: "ヤマダ タロウ",
      applicant_birth_date: Date.new(1990, 5, 15),
      applicant_gender: 1,
      applicant_is_corporate: false,
      contact1_address1: "東京都練馬区富士見台1-1-1",
      contact1_address2: "サンプルマンション101",
      contact1_postal_code: "176-0021",
      contact1_phone1: "090-1234-5678",
      contact1_email: "yamada@example.com",
      contact2_address1: "東京都練馬区富士見台1-1-1",
      contact2_address2: "サンプルマンション101",
      contact2_postal_code: "176-0021",
      contact2_phone1: "090-1234-5678",
      contact2_email: "yamada@example.com",
      workplace_name: "サンプル株式会社",
      workplace_address: "東京都千代田区丸の内1-1-1",
      workplace_postal_code: "100-0005",
      workplace_phone: "03-1234-5678",
      emergency_contact_name: "山田 花子",
      emergency_contact_phone: "090-9876-5432",
      emergency_contact_relationship: "配偶者",
      application_date: Time.current - 7.days,
      move_in_date: Date.current + 14.days,
      room_id: "101"
    },
    {
      entry_head_id: "TEST002",
      property_name: "ル･リオンFREYER南砂EAST 205",
      applicant_name: "佐藤 花子",
      applicant_name_kana: "サトウ ハナコ",
      applicant_birth_date: Date.new(1995, 8, 20),
      applicant_gender: 2,
      applicant_is_corporate: false,
      contact1_address1: "東京都江東区南砂2-2-2",
      contact1_address2: "",
      contact1_postal_code: "136-0076",
      contact1_phone1: "080-2345-6789",
      contact1_email: "sato@example.com",
      contact2_address1: "東京都江東区南砂2-2-2",
      contact2_address2: "",
      contact2_postal_code: "136-0076",
      contact2_phone1: "080-2345-6789",
      contact2_email: "sato@example.com",
      workplace_name: "テスト商事株式会社",
      workplace_address: "東京都港区六本木1-1-1",
      workplace_postal_code: "106-0032",
      workplace_phone: "03-2345-6789",
      emergency_contact_name: "佐藤 一郎",
      emergency_contact_phone: "090-8765-4321",
      emergency_contact_relationship: "父",
      application_date: Time.current - 5.days,
      move_in_date: Date.current + 21.days,
      room_id: "205"
    }
  ]

  test_entries.each do |entry_data|
    job.contract_entries.create!(entry_data)
  end

  puts "Created AgenticJob ##{job.id} with #{job.contract_entries.count} contract entries"
  job
end

# ローカルのマスターCSVをActive Storageに添付
def attach_master_csvs(job)
  puts "\nAttaching master CSV files..."

  customer_master_path = Rails.root.join('docs', 'master_customers.csv')
  property_master_path = Rails.root.join('docs', 'master_properties.csv')

  if File.exist?(customer_master_path)
    job.customer_master.attach(
      io: File.open(customer_master_path),
      filename: 'master_customers.csv',
      content_type: 'text/csv'
    )
    puts "✓ Attached customer master (#{File.size(customer_master_path)} bytes)"
  else
    puts "✗ Customer master not found at: #{customer_master_path}"
    return false
  end

  if File.exist?(property_master_path)
    job.property_master.attach(
      io: File.open(property_master_path),
      filename: 'master_properties.csv',
      content_type: 'text/csv'
    )
    puts "✓ Attached property master (#{File.size(property_master_path)} bytes)"
  else
    puts "✗ Property master not found at: #{property_master_path}"
    return false
  end

  true
end

# CSVを生成
def generate_csvs(job)
  puts "\n" + "="*60
  puts "Generating Customer CSV..."
  puts "="*60

  begin
    job.generate_customers_csv
    puts "✓ Customer CSV generated successfully"

    # 生成されたファイルを確認
    latest_customer_csv = Dir.glob(Rails.root.join('docs', "customers_#{job.id}_*.csv")).max_by { |f| File.mtime(f) }
    if latest_customer_csv
      puts "  File: #{File.basename(latest_customer_csv)}"
      puts "  Size: #{File.size(latest_customer_csv)} bytes"
      puts "  Lines: #{File.readlines(latest_customer_csv).count}"
    end
  rescue => e
    puts "✗ Error generating customer CSV: #{e.message}"
    puts e.backtrace.first(5)
    return false
  end

  puts "\n" + "="*60
  puts "Generating Contracts CSV..."
  puts "="*60

  begin
    job.generate_contracts_csv
    puts "✓ Contracts CSV generated successfully"

    # 生成されたファイルを確認
    latest_contracts_csv = Dir.glob(Rails.root.join('docs', "contracts_#{job.id}_*.csv")).max_by { |f| File.mtime(f) }
    if latest_contracts_csv
      puts "  File: #{File.basename(latest_contracts_csv)}"
      puts "  Size: #{File.size(latest_contracts_csv)} bytes"
      puts "  Lines: #{File.readlines(latest_contracts_csv).count}"
    end
  rescue => e
    puts "✗ Error generating contracts CSV: #{e.message}"
    puts e.backtrace.first(5)
    return false
  end

  true
end

# 生成されたCSVの内容を表示
def display_csv_preview(job)
  puts "\n" + "="*60
  puts "Customer CSV Preview (first 3 lines):"
  puts "="*60

  latest_customer_csv = Dir.glob(Rails.root.join('docs', "customers_#{job.id}_*.csv")).max_by { |f| File.mtime(f) }
  if latest_customer_csv
    File.open(latest_customer_csv, 'r:UTF-8') do |f|
      3.times do
        line = f.gets
        break unless line
        # 長い行は切り詰める
        puts line[0..150] + (line.length > 150 ? "..." : "")
      end
    end
  end

  puts "\n" + "="*60
  puts "Contracts CSV Preview (first 3 lines):"
  puts "="*60

  latest_contracts_csv = Dir.glob(Rails.root.join('docs', "contracts_#{job.id}_*.csv")).max_by { |f| File.mtime(f) }
  if latest_contracts_csv
    File.open(latest_contracts_csv, 'r:UTF-8') do |f|
      3.times do
        line = f.gets
        break unless line
        puts line[0..150] + (line.length > 150 ? "..." : "")
      end
    end
  end
end

# 顧客コードの検証
def verify_customer_codes(job)
  puts "\n" + "="*60
  puts "Verifying Customer Codes:"
  puts "="*60

  job.contract_entries.reload.each do |entry|
    puts "Entry #{entry.entry_head_id}: customer_code = #{entry.customer_code}"
  end
end

# メイン処理
begin
  puts "="*60
  puts "Test Script: Generate CSV without OBIC7 Access"
  puts "="*60

  # 既存のテストデータを削除（オプション）
  print "\nDelete existing test data? (y/N): "
  response = STDIN.gets.chomp.downcase
  if response == 'y'
    AgenticJob.where(source_system: "イタンジ").destroy_all
    puts "✓ Deleted existing test data"
  end

  # ステップ1: テストデータを作成
  job = create_test_data

  # ステップ2: マスターCSVを添付
  unless attach_master_csvs(job)
    puts "\n✗ Failed to attach master CSV files. Exiting."
    exit 1
  end

  # ステップ3: CSVを生成
  unless generate_csvs(job)
    puts "\n✗ Failed to generate CSV files. Exiting."
    exit 1
  end

  # ステップ4: 顧客コードを検証
  verify_customer_codes(job)

  # ステップ5: 生成されたCSVのプレビューを表示
  display_csv_preview(job)

  puts "\n" + "="*60
  puts "✓ Test completed successfully!"
  puts "="*60
  puts "\nGenerated files:"
  puts "  - docs/customers_#{job.id}_*.csv"
  puts "  - docs/contracts_#{job.id}_*.csv"

rescue => e
  puts "\n✗ Test failed with error: #{e.message}"
  puts e.backtrace.first(10)
  exit 1
end
