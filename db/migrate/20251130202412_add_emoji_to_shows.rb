class AddEmojiToShows < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :emoji, :string
  end
end
