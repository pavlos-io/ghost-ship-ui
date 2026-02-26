class AddStatusAndResultToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :status, :string, default: "queued", null: false
    add_column :runs, :result, :text
  end
end
