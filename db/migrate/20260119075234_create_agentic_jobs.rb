class CreateAgenticJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :agentic_jobs do |t|
      t.datetime :executed_at
      t.string :source_system
      t.string :destination_system
      t.string :status
      t.integer :record_count
      t.boolean :action_required
      t.text :error_message

      t.timestamps
    end
  end
end
