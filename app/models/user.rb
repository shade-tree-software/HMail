require 'userfriend'
require 'friend'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         #:timeoutable,
         :registerable,
         # :recoverable,
         # :rememberable,
         :trackable,
         :validatable
  validates :email_pw, confirmation: true
  validates :email_pw_confirmation, presence: true

  has_many :emails
  has_many :userfriends
  has_many :friends, :through => :userfriends

  attr_encrypted :email_pw, :key => ENV['ENCRYPTION_KEY']
end
