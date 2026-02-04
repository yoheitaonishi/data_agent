class AgenticJob < ApplicationRecord
  has_many :contract_entries, dependent: :nullify
  has_one_attached :customers
  has_one_attached :contracts

  # System names
  SOURCE_SYSTEM_ITANDI = "イタンジ"
  DESTINATION_SYSTEM_OBIC7 = "OBIC7"

  # Status constants
  STATUS_PROCESSING = "processing"
  STATUS_SUCCESS = "success"
  STATUS_WARNING = "warning"
  STATUS_ERROR = "error"

  # Create contract data scraping job record
  def self.create_scraping_job
    create!(
      source_system: SOURCE_SYSTEM_ITANDI,
      destination_system: DESTINATION_SYSTEM_OBIC7,
      status: STATUS_PROCESSING,
      executed_at: Time.current,
      action_required: false
    )
  end

  # Execute OBIC7 CSV import
  def self.execute_obic7_import
    job = create!(
      source_system: "System", # or maybe "DB"
      destination_system: DESTINATION_SYSTEM_OBIC7,
      status: STATUS_PROCESSING,
      executed_at: Time.current,
      action_required: false
    )

    begin
      importer = Obic7CsvImportService.new
      # method name in service is execute
      importer.execute
      
      # Assuming success if no error raised
      job.update!(
        status: STATUS_SUCCESS,
        record_count: 0, # Placeholder, maybe update service to return count
        action_required: false
      )
      job
    rescue => e
      job.update!(
        status: STATUS_ERROR,
        error_message: e.message,
        action_required: true
      )
      job
    end
  end

  def generate_customers_csv
    require 'csv'
    
    columns = %w[
      id entry_head_id application_date entry_status
      applicant_type applicant_name applicant_email applicant_edit_permission
      property_name room_id address rent management_fee deposit guarantee_deposit key_money
      guarantee_company guarantee_result joint_guarantor_usage
      broker_company_name broker_phone broker_staff_name broker_staff_email broker_staff_phone
      contract_method application_method detail_url registration_number priority area
      created_at updated_at
    ]

    csv_data = CSV.generate("\xEF\xBB\xBF") do |csv|
      csv << columns
      contract_entries.each do |entry|
        csv << columns.map { |col| entry.send(col) }
      end
    end

    customers.attach(
      io: StringIO.new(csv_data),
      filename: "customers_#{id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv",
      content_type: 'text/csv'
    )
  end

  def generate_contracts_csv
    require 'csv'
    
    columns = %w[
      id entry_head_id application_date entry_status
      applicant_type applicant_name applicant_email applicant_edit_permission
      property_name room_id address rent management_fee deposit guarantee_deposit key_money
      guarantee_company guarantee_result joint_guarantor_usage
      broker_company_name broker_phone broker_staff_name broker_staff_email broker_staff_phone
      contract_method application_method detail_url registration_number priority area
      created_at updated_at
    ]

    csv_data = CSV.generate("\xEF\xBB\xBF") do |csv|
      csv << columns
      contract_entries.each do |entry|
        csv << columns.map { |col| entry.send(col) }
      end
    end

    contracts.attach(
      io: StringIO.new(csv_data),
      filename: "contracts_#{id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv",
      content_type: 'text/csv'
    )
  end
end
