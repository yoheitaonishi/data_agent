class AgenticJobsController < ApplicationController
  def show
    @agentic_job = AgenticJob.find(params[:id])
    @contract_entries = @agentic_job.contract_entries.order(created_at: :desc)
  end

  def execute
    job = AgenticJob.create_scraping_job
    ScrapeContractDataJob.perform_later(job.id)
    redirect_to root_path, notice: "契約データの取得を開始しました。"
  end
end
