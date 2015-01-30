require 'user'
require 'friend'

class Userfriend < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend
end
