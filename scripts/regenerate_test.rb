#!/usr/bin/env ruby
require_relative 'config/environment'

# Entry ID: 6 (申し込み受付くんの実データ)で再度CSV生成

# 新しいAgenticJobを作成
job = AgenticJob.create!(
  source_system: "イタンジ",
  destination_system: "OBIC7",
  status: "processing",
  executed_at: Time.current,
  action_required: false
)

# Entry ID: 6をこのジョブに紐付け（既存の紐付けをクリア）
entry = ContractEntry.find(6)
entry.update!(agentic_job_id: job.id, customer_code: nil)

puts "=== 顧客マスタから17624を削除後の再実行 ==="
puts "AgenticJob ID: #{job.id}"
puts ""

# マスターCSVを添付
customer_master_path = Rails.root.join("docs", "master_customers.csv")
property_master_path = Rails.root.join("docs", "master_properties.csv")

job.customer_master.attach(
  io: File.open(customer_master_path),
  filename: "master_customers.csv",
  content_type: "text/csv"
)

job.property_master.attach(
  io: File.open(property_master_path),
  filename: "master_properties.csv",
  content_type: "text/csv"
)

# 最大値を確認
max_code = job.send(:get_max_customer_code_from_master)
puts "顧客マスタ最大値: #{format("%010d", max_code)} (#{max_code})"
puts "次の顧客コード: #{format("%010d", max_code + 1)} (#{max_code + 1})"
puts ""

# CSVを生成
puts "顧客CSV生成中..."
job.generate_customers_csv

puts "契約CSV生成中..."
job.generate_contracts_csv

# 結果を表示
entry.reload
puts ""
puts "=== 生成結果 ==="
puts "生成された顧客コード: #{entry.customer_code}"
puts ""

# ファイル名を取得
customer_csv = Dir.glob(Rails.root.join("docs", "customers_#{job.id}_*.csv")).first
contracts_csv = Dir.glob(Rails.root.join("docs", "contracts_#{job.id}_*.csv")).first

puts "生成されたファイル:"
puts "  📄 #{File.basename(customer_csv)}"
puts "  📄 #{File.basename(contracts_csv)}"
