class Email < ActiveRecord::Base
  belongs_to :user

  def subject
    Mail.read_from_string(self.body).subject
  end

  def from
    Mail.read_from_string(self.body).from[0]
  end

  def text
    parts = Mail.read_from_string(self.body).parts
    body_text = ''
    parts.each do |part|
      body_text << part.decoded if part.content_type.start_with? 'text/plain'
    end
    body_text
  end
end
