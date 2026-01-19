class AgenticJobsController < ApplicationController
  def show
    @agentic_job = AgenticJob.find(params[:id])
    @contract_entries = @agentic_job.contract_entries.order(created_at: :desc)
  end

  def execute
    job = AgenticJob.execute_contract_scraping
    redirect_to agentic_job_path(job), notice: "契約データの取得を開始しました。"
  end
end
