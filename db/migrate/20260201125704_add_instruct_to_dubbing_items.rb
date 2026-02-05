class AddInstructToDubbingItems < ActiveRecord::Migration[8.1]
  def change
    add_column :dubbing_items, :instruct, :text
  end
end
