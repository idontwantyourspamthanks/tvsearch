class Admin::DatabaseController < ApplicationController
  before_action :require_admin!

  def download
    db_config = ActiveRecord::Base.connection_db_config
    db_path = db_config.database

    unless File.exist?(db_path)
      redirect_to admin_root_path, alert: "Database file not found"
      return
    end

    # Generate filename with timestamp
    filename = "production-#{Time.current.strftime('%Y%m%d-%H%M%S')}.sqlite3"

    send_file db_path,
              filename: filename,
              type: "application/x-sqlite3",
              disposition: "attachment"
  end
end
