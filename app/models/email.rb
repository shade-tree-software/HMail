class Email < ActiveRecord::Base
  belongs_to :user

  attr_accessor :message
  attr_writer :subject
  attr_writer :to

  def subject
    if self.body.nil?
      ''
    else
      Mail.read_from_string(self.body).subject
    end
  end

  def from
    if self.body.nil?
      ''
    else
      Mail.read_from_string(self.body).from[0]
    end
  end

  def to
    if self.body.nil?
      ''
    else
      recipient = Mail.read_from_string(self.body).to
      if recipient.size > 1
        recipient
      else
        recipient[0]
      end
    end
  end

  def date
    if self.body.nil?
      0
    else
      Mail.read_from_string(self.body).date.to_i
    end
  end

  def friendly_date
    if self.body.nil?
      Time.new(0).localtime.ctime
    else
      Mail.read_from_string(self.body).date.to_time.localtime.ctime
    end
  end

  def text
    if self.body.nil?
      ''
    else
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

end
