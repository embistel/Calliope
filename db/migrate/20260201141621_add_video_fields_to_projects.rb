class AddVideoFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :video_status, :string
    add_column :projects, :video_progress, :integer
  end
end
