class ContractDataJob < ApplicationJob
  queue_as :default

  def perform
    scraper = MoushikomiScraperService.new
    result = scraper.scrape_contract_data

    # Store result in cache for controller to retrieve
    # Using Rails.cache with 10 minute expiration
    Rails.cache.write("contract_data_result", result, expires_in: 10.minutes)

    result
  end
end
