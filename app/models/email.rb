class Email < ActiveRecord::Base
  belongs_to :user

  def subject
    Mail.read_from_string(self.body).subject
  end

  def from
    Mail.read_from_string(self.body).from[0]
  end

  def date
    Mail.read_from_string(self.body).date.to_i
  end

  def friendly_date
    Mail.read_from_string(self.body).date.to_time.localtime.ctime
  end

  def text
    mail = Mail.read_from_string(self.body)
    body_text = ''
    if mail.multipart?
      mail.parts.each do |part|
        body_text << part.decoded if part.content_type.start_with? 'text/plain'
      end
    else
      body_text = mail.decoded
      body_text = body_text.gsub(/>\s*/, '>').gsub(/\s*</, '<') if mail.content_type.start_with? 'text/html'
    end
    body_text
  end
end
