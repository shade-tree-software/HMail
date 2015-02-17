require 'friend'

class Email < ActiveRecord::Base
  belongs_to :user

  attr_accessor :message

  def self.sync_mailbox(user, mailbox_type)
    case mailbox_type
      when 'sent'
        Email.select(:id, :to, :subject, :date)
            .where(user_id: user.id)
            .where(sent: true)
            .order(date: :desc)
      when 'archived'
        Email.select(:id, :from, :subject, :date)
            .where(user_id: user.id)
            .where("\"from\" in (?)", user.friends.select(:email))
            .where(archived: true)
            .order(date: :desc)
      when 'blacklisted'
        Email.where(user_id: user.id)
            .where("\"from\" not in (?)", user.friends.select(:email))
            .where("date < #{Time.now.to_i - 604800}").delete_all
        Email.select(:id, :from, :subject, :date, :unread)
            .where(user_id: user.id)
            .where("\"from\" not in (?)", user.friends.select(:email))
            .where(sent: false)
            .order(date: :desc)
      else # inbox
        Email.select(:id, :from, :subject, :date, :unread)
            .where(user_id: user.id)
            .where("\"from\" in (?)", user.friends.select(:email))
            .where(archived: false)
            .where(sent: false)
            .order(date: :desc)
    end
  end

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
    end
  end

  def build_reply
    friend = Friend.find_by_email(from)
    friends = [[friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id]]
    original_lines = text.split("\n").collect do |line|
      "> #{line}"
    end
    preamble = original_lines.empty? ? '' : "\n\nOn #{Time.at(date).utc.to_s} #{from} wrote: \n"
    reply_text = preamble + original_lines.join("\n")
    preamble = (subject.downcase.start_with? 're:') ? '' : 'Re: '
    new_subject = preamble + subject
    {recipients: friends, subject: new_subject, reply_text: reply_text, is_reply: true}
  end

end
