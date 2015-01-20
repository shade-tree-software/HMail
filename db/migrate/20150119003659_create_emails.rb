class CreateEmails < ActiveRecord::Migration
  def change
    create_table :emails do |t|
      t.string :body
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
