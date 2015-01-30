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
      sender = Mail.read_from_string(self.body).from
      if sender.is_a? Array
        sender[0]
      else
        sender
      end
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
    begin
      Mail.read_from_string(self.body).date.to_time.localtime.ctime
    rescue
      Time.new(0).localtime.ctime
    end
  end

  def text
    if self.body.nil?
      ''
    else
      mail = Mail.read_from_string(self.body)
      if mail.multipart?
        parts = mail.parts
      else
        parts = [mail]
      end
      parts.collect do |part|
        if part.content_type.start_with? 'text/plain'
          part.decoded
        else
          "<p style=\"color:red\">Attachment Removed:[#{part.content_type}]</p>"
        end
      end.join("\n")
      #body_text = body_text.gsub(/>\s*/, '>').gsub(/\s*</, '<') if mail.content_type.start_with? 'text/html'
    end
  end

end
