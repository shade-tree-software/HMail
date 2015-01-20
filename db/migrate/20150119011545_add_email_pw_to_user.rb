class AddEmailPwToUser < ActiveRecord::Migration
  def change
    add_column :users, :email_pw, :string
  end
end
