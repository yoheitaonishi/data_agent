class AgenticJobsController < ApplicationController
  def show
    @agentic_job = AgenticJob.find(params[:id])
  end
end
