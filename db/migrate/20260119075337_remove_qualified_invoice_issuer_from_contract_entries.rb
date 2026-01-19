class RemoveQualifiedInvoiceIssuerFromContractEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :contract_entries, :qualified_invoice_issuer, :string
  end
end
