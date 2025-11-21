class AddImagePathToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :image_path, :string
    add_column :episodes, :image_updated_at, :datetime
    add_index :episodes, :image_updated_at
  end
end
