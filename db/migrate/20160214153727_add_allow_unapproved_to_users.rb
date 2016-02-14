class AddAllowUnapprovedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :allow_unapproved, :boolean, :default => false
  end
end
