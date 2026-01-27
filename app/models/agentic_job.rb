class AgenticJob < ApplicationRecord
  has_many :contract_entries, dependent: :nullify

  # System names
  SOURCE_SYSTEM_ITANDI = "イタンジ"
  DESTINATION_SYSTEM_OBIC7 = "OBIC7"

  # Status constants
  STATUS_PROCESSING = "processing"
  STATUS_SUCCESS = "success"
  STATUS_WARNING = "warning"
  STATUS_ERROR = "error"

  # Execute contract data scraping
  def self.execute_contract_scraping
    job = create!(
      source_system: SOURCE_SYSTEM_ITANDI,
      destination_system: DESTINATION_SYSTEM_OBIC7,
      status: STATUS_PROCESSING,
      executed_at: Time.current,
      action_required: false
    )

    begin
      scraper = MoushikomiScraperService.new
      result = scraper.scrape_contract_data(agentic_job_id: job.id)

      if result[:success]
        job.update!(
          status: STATUS_SUCCESS,
          record_count: result[:count],
          action_required: false
        )
      else
        job.update!(
          status: STATUS_ERROR,
          error_message: result[:error],
          action_required: true
        )
      end

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
end
