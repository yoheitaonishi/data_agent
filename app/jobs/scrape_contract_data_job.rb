class ScrapeContractDataJob < ApplicationJob
  queue_as :default

  def perform(agentic_job_id)
    job = AgenticJob.find(agentic_job_id)

    begin
      scraper = MoushikomiScraperService.new
      result = scraper.scrape_contract_data(agentic_job_id: job.id)

      if result[:success]
        job.update!(
          status: AgenticJob::STATUS_SUCCESS,
          record_count: result[:count],
          action_required: false
        )
      else
        job.update!(
          status: AgenticJob::STATUS_ERROR,
          error_message: result[:error],
          action_required: true
        )
      end
    rescue => e
      job.update!(
        status: AgenticJob::STATUS_ERROR,
        error_message: e.message,
        action_required: true
      )
    end
  end
end
