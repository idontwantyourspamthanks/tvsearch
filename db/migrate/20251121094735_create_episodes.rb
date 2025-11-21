class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes do |t|
      t.string :show_name, null: false
      t.string :title, null: false
      t.integer :season_number
      t.integer :episode_number
      t.text :description
      t.date :aired_on

      t.timestamps
    end

    add_index :episodes, [:show_name, :title]
  end
end
