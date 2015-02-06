class AddConvenienceFieldsToEmails < ActiveRecord::Migration
  def change
    add_column :emails, :subject, :string
    add_column :emails, :to, :string
    add_column :emails, :from, :string
    add_column :emails, :date, :integer
    add_column :emails, :friendly_date, :string
  end
end
