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
      when 'unapproved'
        deleteables = Email.where(user_id: user.id)
                          .where("\"from\" not in (?)", user.friends.select(:email))
                          .where(sent: false)
                          .where(deleted: [false, nil])
                          .where("date < #{Time.now.to_i - 604800}")
        deleteables.each do |d|
          d[:deleted] = true
          d.save
        end
        Email.select(:id, :from, :subject, :date, :unread)
            .where(user_id: user.id)
            .where("\"from\" not in (?)", user.friends.select(:email))
            .where(sent: false)
            .where(deleted: [false, nil])
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
    recipients = (to.split(',') << from) - [current_user.email]
    friendly_emails = current_user.friends.map { |f| f.email }
    friendly_ids = current_user.friends.map { |f| f.id }
    recipients.select! { |r| friendly_emails.include? r }
    recipient_ids = recipients.map { |r| friendly_ids[friendly_emails.index(r)] }
    friends = current_user.friends.map do |friend|
      [friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id]
    end
    original_lines = text(text_only: true).split("\n").collect do |line|
      "> #{line}"
    end
    preamble = original_lines.empty? ? '' : "\n\nOn #{Time.at(date).utc.to_s} #{from} wrote: \n"
    reply_text = preamble + original_lines.join("\n")
    preamble = (subject.downcase.start_with? 're:') ? '' : 'Re: '
    new_subject = preamble + subject
    {recipients: recipient_ids, friends: friends, subject: new_subject, reply_text: reply_text, is_reply: true}
  end

end
