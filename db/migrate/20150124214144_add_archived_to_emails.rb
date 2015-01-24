class AddArchivedToEmails < ActiveRecord::Migration
  def change
    add_column :emails, :archived, :boolean
  end
end
