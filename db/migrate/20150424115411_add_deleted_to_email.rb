class AddDeletedToEmail < ActiveRecord::Migration
  def change
    add_column :emails, :deleted, :boolean
  end
end
