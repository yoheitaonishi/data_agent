class AddStepToAgenticJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :agentic_jobs, :step, :integer
  end
end
