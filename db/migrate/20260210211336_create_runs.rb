class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.string :creator
      t.string :source

      t.timestamps
    end
  end
end
