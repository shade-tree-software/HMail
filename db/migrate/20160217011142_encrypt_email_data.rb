class EncryptEmailData < ActiveRecord::Migration
  def change
    rename_column :emails, :sender, :encrypted_sender
    rename_column :emails, :recipients, :encrypted_recipients
    rename_column :emails, :subject, :encrypted_subject
    rename_column :emails, :body, :encrypted_body
  end
end
