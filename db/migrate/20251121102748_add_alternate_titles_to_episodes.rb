class AddAlternateTitlesToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :alternate_titles, :text
  end
end
