class AddEncryptedSenderNameToEmails < ActiveRecord::Migration
  def change
    add_column :emails, :encrypted_sender_name, :string
  end
end
