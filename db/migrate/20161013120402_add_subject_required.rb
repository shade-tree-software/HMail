class AddSubjectRequired < ActiveRecord::Migration
  def change
    add_column :users, :subject_required, :boolean
  end
end
