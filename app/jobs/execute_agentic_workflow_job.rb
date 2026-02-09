class ExecuteAgenticWorkflowJob < ApplicationJob
  queue_as :default

  def perform(agentic_job_id)
    job = AgenticJob.find(agentic_job_id)

    # === Step 1: Itanji Data Extract ===
    job.update!(status: AgenticJob::STATUS_PROCESSING, step: :itanji_data_extract)
    
    scraper = MoushikomiScraperService.new
    result = scraper.scrape_contract_data(agentic_job_id: job.id)

    unless result[:success]
      job.update!(
        status: AgenticJob::STATUS_ERROR,
        error_message: result[:error],
        action_required: true
      )
      return
    end

    # Ensure Contract CSV is generated (Customer CSV is generated in scraper)
    job.generate_contracts_csv

    # === Step 2: OBIC7 Customer Import ===
    job.update!(step: :obic7_customer_import)
    
    begin
      customer_importer = Obic7CsvImportService.new(agentic_job_id: job.id)
      customer_importer.execute_customer_csv_import

      # 顧客マスタを保存
      customer_exporter = Obic7ExportMasterService.new(agentic_job_id: job.id)
      customer_exporter.execute_export_customer

      # 物件マスタを保存
      property_exporter = Obic7ExportMasterService.new(agentic_job_id: job.id)
      property_exporter.execute_export_properties
    rescue => e
      job.update!(
        status: AgenticJob::STATUS_ERROR,
        error_message: "Customer Import Failed: #{e.message}",
        action_required: true
      )
      return
    end

    # === Step 3: OBIC7 Contract Import ===
    job.update!(step: :obic_7_contract_import)


    
    begin
      contract_importer = Obic7CsvImportService.new(agentic_job_id: job.id)
      contract_importer.execute_contract_csv_import
    rescue => e
      job.update!(
        status: AgenticJob::STATUS_ERROR,
        error_message: "Contract Import Failed: #{e.message}",
        action_required: true
      )
      return
    end

    # === Complete ===
    job.update!(
      status: AgenticJob::STATUS_SUCCESS,
      record_count: result[:count],
      action_required: false
    )
  end
end
