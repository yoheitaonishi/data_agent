class RemoveBalconyAreaFromContractEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :contract_entries, :balcony_area, :decimal
  end
end
