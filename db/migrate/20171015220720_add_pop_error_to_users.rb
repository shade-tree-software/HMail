class AddPopErrorToUsers < ActiveRecord::Migration
  def change
    add_column :users, :pop_error, :boolean
  end
end
