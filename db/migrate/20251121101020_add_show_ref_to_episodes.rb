class AddShowRefToEpisodes < ActiveRecord::Migration[8.0]
  def up
    add_reference :episodes, :show, foreign_key: true

    Episode.reset_column_information
    Show.reset_column_information

    Episode.find_each do |episode|
      show = Show.find_or_create_by!(name: episode.show_name.presence || "Unknown")
      episode.update_columns(show_id: show.id)
    end

    change_column_null :episodes, :show_id, false
    remove_column :episodes, :show_name, :string
  end

  def down
    add_column :episodes, :show_name, :string

    Episode.reset_column_information

    Episode.includes(:show).find_each do |episode|
      episode.update_columns(show_name: episode.show&.name)
    end

    remove_reference :episodes, :show, foreign_key: true
  end
end
