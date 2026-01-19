class AddAgenticJobIdToContractEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :contract_entries, :agentic_job_id, :integer
    add_index :contract_entries, :agentic_job_id
  end
end
