class AddUniqueToEmails < ActiveRecord::Migration
  def change
    execute <<-sql
      alter table emails
      add unique (user_id, subject, "to", "from", date);
    sql
  end
end
