class AddTvdbIdsToShowsAndEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :tvdb_id, :bigint
    add_index :shows, :tvdb_id, unique: true

    add_column :episodes, :tvdb_id, :bigint
    add_index :episodes, :tvdb_id, unique: true
  end
end
