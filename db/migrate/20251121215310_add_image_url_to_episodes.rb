class AddImageUrlToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :image_url, :string
  end
end
