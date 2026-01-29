class CreateDubbingItems < ActiveRecord::Migration[8.1]
  def change
    create_table :dubbing_items do |t|
      t.references :project, null: false, foreign_key: true
      t.text :content
      t.integer :position

      t.timestamps
    end
  end
end
