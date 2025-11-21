class CreateShows < ActiveRecord::Migration[8.0]
  def change
    create_table :shows do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :shows, :name, unique: true
  end
end
