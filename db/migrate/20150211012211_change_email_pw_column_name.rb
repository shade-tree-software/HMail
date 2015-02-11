class ChangeEmailPwColumnName < ActiveRecord::Migration
  def change
    rename_column :users, :email_pw, :encrypted_email_pw
  end
end
