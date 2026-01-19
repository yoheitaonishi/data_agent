class RemoveUnusedFieldsFromContractEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :contract_entries, :parking_fee, :decimal
    remove_column :contract_entries, :other_fees, :text
    remove_column :contract_entries, :renewal_fee, :decimal
    remove_column :contract_entries, :building_structure, :string
    remove_column :contract_entries, :floor, :string
    remove_column :contract_entries, :room_status, :string
    remove_column :contract_entries, :contract_start_date, :date
    remove_column :contract_entries, :move_in_date, :date
    remove_column :contract_entries, :contract_period, :string
  end
end
