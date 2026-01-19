class AddApplicantTypeToContractEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :contract_entries, :applicant_type, :string
  end
end
