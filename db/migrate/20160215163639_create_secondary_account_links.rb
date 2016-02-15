class CreateSecondaryAccountLinks < ActiveRecord::Migration
  def change
    create_table :secondary_account_links do |t|
      t.integer :primary_user_id
      t.integer :secondary_user_id
    end
  end
end
