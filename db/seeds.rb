[
  { executed_at: '2024/05/20 14:30:05', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'processing', record_count: 1205, action_required: false, error_message: '' },
  { executed_at: '2024/05/20 10:00:00', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'error', record_count: 45, action_required: true, error_message: '行 45: データ形式が無効です（物件情報の必須項目不足）。' },
  { executed_at: '2024/05/19 23:00:00', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'success', record_count: 54320, action_required: false, error_message: '' },
  { executed_at: '2024/05/19 18:15:22', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'warning', record_count: 890, action_required: true, error_message: '一部のデータがスキップされました（重複キー）。' },
  { executed_at: '2024/05/19 12:00:00', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'success', record_count: 200, action_required: false, error_message: '' },
  { executed_at: '2024/05/18 09:30:00', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'success', record_count: 1500, action_required: false, error_message: '' },
  { executed_at: '2024/05/18 08:00:00', source_system: 'イタンジ', destination_system: 'OBIC7', status: 'error', record_count: 0, action_required: true, error_message: 'API接続タイムアウトが発生しました。再試行してください。' }
].each do |data|
  AgenticJob.create!(data)
end
