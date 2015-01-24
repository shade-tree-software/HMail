class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
  :registerable,
  # :recoverable,
  # :rememberable,
  :trackable, :validatable
  validates :email_pw, confirmation: true
  validates :email_pw_confirmation, presence: true

  has_many :emails
end
