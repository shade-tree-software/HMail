class Email < ActiveRecord::Base
  belongs_to :user

  def subject
    Mail.read_from_string(body).subject
  end

  def from
    Mail.read_from_string(body).from
  end
end
