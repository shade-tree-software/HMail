require 'userfriend'

class Friend < ActiveRecord::Base
  has_many :userfriends
  has_many :users, :through => :userfriends
end
