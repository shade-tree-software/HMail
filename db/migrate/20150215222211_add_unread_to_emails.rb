class AddUnreadToEmails < ActiveRecord::Migration
  def change
    add_column :emails, :unread, :boolean
  end
end
