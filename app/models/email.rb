require 'friend'

class Email < ActiveRecord::Base
  belongs_to :user

  attr_accessor :message

  def text(args = {})
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
          if args[:show_warnings]
            "<p style=\"color:red\">Attachment Removed: [#{part.content_type}]</p>"
          else
            nil
          end
        end
      end.join("\n")
      #body_text = body_text.gsub(/>\s*/, '>').gsub(/\s*</, '<') if mail.content_type.start_with? 'text/html'
    end
  end

  def build_reply
    friend = Friend.find_by_email(from)
    friends = [[friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id]]
    original_lines = text.split("\n").collect do |line|
      "> #{line}"
    end
    preamble = original_lines.empty? ? '' : "\n\nOn #{friendly_date} #{from} wrote: \n"
    reply_text = preamble + original_lines.join("\n")
    preamble = (subject.downcase.start_with? 're:') ? '' : 'Re: '
    new_subject = preamble + subject
    {recipients: friends, subject: new_subject, reply_text: reply_text, is_reply: true }
  end

end
