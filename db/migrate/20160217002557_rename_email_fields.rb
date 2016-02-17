class RenameEmailFields < ActiveRecord::Migration
  def change
    rename_column :emails, :to, :recipients
    rename_column :emails, :from, :sender
  end
end
