class Obic7ContractImportJob < ApplicationJob
  queue_as :default

  def perform(agentic_job_id)
    job = AgenticJob.find(agentic_job_id)

    begin
      job.update!(status: AgenticJob::STATUS_PROCESSING, step: :obic_7_contract_import)

      importer = Obic7CsvImportService.new(agentic_job_id: job.id)
      importer.execute_contract_csv_import

      job.update!(
        status: AgenticJob::STATUS_SUCCESS,
        action_required: false
      )
    rescue => e
      job.update!(
        status: AgenticJob::STATUS_ERROR,
        error_message: e.message,
        action_required: true
      )
    end
  end
end
