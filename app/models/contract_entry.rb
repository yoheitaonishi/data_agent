class ContractEntry < ApplicationRecord
  # Validations
  validates :entry_head_id, presence: true
  validates :property_name, presence: true
  validates :applicant_name, presence: true

  # Serialization for additional_data JSON field
  serialize :additional_data, coder: JSON

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_application_date, -> { order(application_date: :desc) }

  # Format money fields for display
  def formatted_rent
    rent ? "#{rent.to_i.to_s(:delimited)} 円" : "-"
  end

  def formatted_management_fee
    management_fee ? "#{management_fee.to_i.to_s(:delimited)} 円" : "-"
  end

  def formatted_deposit_info
    "#{format_money(deposit)} / #{format_money(key_money)} / #{format_money(guarantee_deposit)}"
  end

  private

  def format_money(amount)
    amount ? "#{amount.to_i.to_s(:delimited)} 円" : "0 円"
  end
end
