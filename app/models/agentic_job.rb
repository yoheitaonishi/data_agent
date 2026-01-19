class AgenticJob < ApplicationRecord
  has_many :contract_entries, dependent: :nullify

  # Execute contract data scraping
  def self.execute_contract_scraping
    job = create!(
      source_system: "申し込み受付くん",
      destination_system: "DataAgent DB",
      status: "processing",
      executed_at: Time.current,
      action_required: false
    )

    begin
      scraper = MoushikomiScraperService.new
      result = scraper.scrape_contract_data(agentic_job_id: job.id)

      if result[:success]
        job.update!(
          status: "completed",
          record_count: result[:count],
          action_required: false
        )
      else
        job.update!(
          status: "failed",
          error_message: result[:error],
          action_required: true
        )
      end

      job
    rescue => e
      job.update!(
        status: "failed",
        error_message: e.message,
        action_required: true
      )
      job
    end
  end
end
