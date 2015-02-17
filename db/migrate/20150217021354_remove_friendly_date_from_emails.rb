class RemoveFriendlyDateFromEmails < ActiveRecord::Migration
  def change
    remove_column :emails, :friendly_date
  end
end
