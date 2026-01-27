class Obic7ExportMasterDataJob < ApplicationJob
  queue_as :default

  def perform(agentic_job_id: nil)
    scraper = Obic7ScraperService.new
    result = scraper.login_and_export_master_data(agentic_job_id: agentic_job_id)

    # Store result in cache for controller to retrieve
    # Using Rails.cache with 10 minute expiration
    Rails.cache.write("obic7_export_master_data_result", result, expires_in: 10.minutes)

    result
  end
end
