class CreateUserfriends < ActiveRecord::Migration
  def change
    create_table :userfriends do |t|
      t.integer :user_id
      t.integer :friend_id
    end
  end
end
