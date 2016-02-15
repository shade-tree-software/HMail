require 'user'

class SecondaryAccountLink < ActiveRecord::Base
  belongs_to :primary_user, class_name: 'User', foreign_key: 'primary_user_id'
  belongs_to :secondary_user, class_name: 'User', foreign_key: 'secondary_user_id'
end
