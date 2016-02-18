require 'friend'

class Email < ActiveRecord::Base
  belongs_to :user

  attr_accessor :message

  attr_encrypted :sender, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :recipients, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :subject, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :body, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')

  def self.friendly_emails(user)
    if ENV['ENCRYPT_EMAIL_DATA'] == 'true'
      user.friends.select(:email).map { |friend| Email.encrypt_sender(friend.email) }
    else
      user.friends.select(:email)
    end
  end

  def self.sync_mailbox(user, mailbox_type)
    case mailbox_type
      when 'sent'
        Email.select(:id, :encrypted_recipients, :encrypted_subject, :date)
            .where(user_id: user.id)
            .where(sent: true)
            .map do |e|
          {
              id: e.id,
              recipients: e.recipients,
              subject: e.subject,
              date: e.date
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
      when 'archived'
        users = [user] + user.secondary_users
        emails = users.map do |u|
          if u.allow_unapproved
            Email.joins(:user).select(:id, :encrypted_sender, :encrypted_subject, :date, :email)
                .where(user_id: u.id)
                .where(deleted: [false, nil])
                .where(archived: true)
          else
            Email.joins(:user).select(:id, :encrypted_sender, :encrypted_subject, :date, :email)
                .where(user_id: u.id)
                .where(encrypted_sender: friendly_emails(u))
                .where(deleted: [false, nil])
                .where(archived: true)
          end
        end
        emails.flatten.compact.map do |e|
          {
              id: e.id,
              sender: e.sender,
              subject: e.subject,
              date: e.date,
              user: e.email.gsub!('@gmail.com','')
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
      when 'unapproved'
        users = [user] + user.secondary_users
        emails = users.map do |u|
          if u.allow_unapproved
            nil
          else
            deleteables = Email.where(user_id: u.id)
                              .where.not(encrypted_sender: friendly_emails(u))
                              .where(sent: false)
                              .where(deleted: [false, nil])
                              .where("date < #{Time.now.to_i - 604800}")
            deleteables.each do |d|
              d[:deleted] = true
              d.save
            end
            Email.joins(:user).select(:id, :encrypted_sender, :date, :unread, :email)
                .where(user_id: u.id)
                .where.not(encrypted_sender: friendly_emails(u))
                .where(sent: false)
                .where(deleted: [false, nil])
          end
        end
        emails.flatten.compact.map do |e|
          {
              id: e.id,
              sender: e.sender,
              date: e.date,
              unread: e.unread,
              user: e.email.gsub!('@gmail.com','')
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
      else # inbox
        users = [user] + user.secondary_users
        emails = users.map do |u|
          if u.allow_unapproved
            Email.joins(:user).select(:id, :encrypted_sender, :encrypted_subject, :date, :unread, :email)
                .where(user_id: u.id)
                .where(archived: false)
                .where(sent: false)
                .where(deleted: [false, nil])
          else
            Email.joins(:user).select(:id, :encrypted_sender, :encrypted_subject, :date, :unread, :email)
                .where(user_id: u.id)
                .where(encrypted_sender: friendly_emails(u))
                .where(archived: false)
                .where(sent: false)
                .where(deleted: [false, nil])
          end
        end
        emails.flatten.compact.map do |e|
          {
              id: e.id,
              sender: e.sender,
              subject: e.subject,
              date: e.date,
              unread: e.unread,
              user: e.email.gsub!('@gmail.com','')
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
    end
  end

  def assemble_parts(part, args)
    if part.multipart?
      part.parts.collect { |sub_part| assemble_parts(sub_part, args) }.compact.join('')
    else
      if part.content_type.nil?
        part.body.to_s # Not sure if this really works.  We don't seem to handle non-multipart messages correctly.
      elsif part.content_type.start_with?('text/html') && !args[:text_only]
        nil
      elsif part.content_type.start_with? 'text/plain'
        part.decoded
      elsif part.content_type.start_with?('image/') && !args[:text_only]
        @image_count += 1
        Dir.mkdir('media') unless Dir.exists?('media')
        tempfile = File.new "media/#{user.id}_#{id}_#{@image_count}_#{part.filename}", 'w', :encoding => 'binary'
        tempfile.write part.decoded
        tempfile.flush
        "<img src=\"/emails/#{id}/image?filename=#{@image_count}_#{part.filename}\" alt=\"Image: #{part.filename}\">"
      else
        if args[:show_warnings]
          "<p style=\"color:red\">Attachment Removed: [#{part.content_type}]</p>"
        else
          nil
        end
      end
    end
  end

  def text(args = {})
    if self.body.nil?
      ''
    else
      @image_count = 0
      assemble_parts Mail.read_from_string(self.body), args
    end
  end

  def build_reply(current_user)
    orig_recipients = (recipients.delete(' ').split(',') << sender) - [current_user.email]
    friendly_emails = current_user.friends.map { |f| f.email }
    friendly_ids = current_user.friends.map { |f| f.id }
    recipients = orig_recipients.select { |r| friendly_emails.include? r }
    recipient_ids = recipients.map { |r| friendly_ids[friendly_emails.index(r)] }
    friends = current_user.friends.map do |friend|
      [friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id, {class: 'emailRecipient'}]
    end
    original_lines = text(text_only: true).split("\n").collect do |line|
      "> #{line}"
    end
    preamble = original_lines.empty? ? '' : "\n\nOn #{Time.at(date).utc.to_s} #{sender} wrote: \n"
    reply_text = preamble + original_lines.join("\n")
    preamble = (subject.downcase.start_with? 're:') ? '' : 'Re: '
    new_subject = preamble + subject
    {
        recipients: current_user.allow_unapproved? ? orig_recipients.join(', ') : recipient_ids,
        friends: friends,
        subject: new_subject,
        reply_text: reply_text,
        is_reply: true,
        thread_participant_count: orig_recipients.size,
        allow_unapproved: current_user.allow_unapproved
    }
  end

end
