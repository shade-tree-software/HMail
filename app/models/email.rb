require 'friend'

class Email < ActiveRecord::Base
  belongs_to :user

  attr_accessor :message

  attr_encrypted :sender, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :recipients, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :subject, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')
  attr_encrypted :body, :key => ENV['ENCRYPTION_KEY'], :if => (ENV['ENCRYPT_EMAIL_DATA'] == 'true')

  EMAILS_PER_PAGE = 8

  def self.friendly_emails(user)
    if ENV['ENCRYPT_EMAIL_DATA'] == 'true'
      user.friends.select(:email).map { |friend| Email.encrypt_sender(friend.email) }
    else
      user.friends.select(:email)
    end
  end

  def self.truncate(string='', len=30)
    (string.length > len) ? (string.slice(0, len).rstrip + '...') : string
  end

  def self.delete_old_unapproved(user)
    unless user.allow_unapproved
      deleteables = Email.where(user: user)
                      .where.not(encrypted_sender: friendly_emails(user))
                      .where(sent: false)
                      .where(deleted: [false, nil])
                      .where("date < #{Time.now.to_i - 604800}")
      deleteables.each do |d|
        d[:deleted] = true
        d.save
      end
    end
  end

  def self.sync_mailbox(user, mailbox_type='inbox', page=1)
    page = page.to_i
    page = (page < 1) ? 1 : page
    case mailbox_type
      when 'sent'
        emails = Email.select(:id, :encrypted_recipients, :encrypted_subject, :date)
                   .where(user_id: user.id)
                   .where(sent: true)
                   .map do |e|
          {
            id: e.id,
            recipients: truncate(e.recipients),
            subject: CGI.escapeHTML(e.subject),
            date: e.date
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
        pages = (emails.size.to_f / EMAILS_PER_PAGE).ceil
        emails = emails.slice((page - 1) * EMAILS_PER_PAGE, EMAILS_PER_PAGE)
        {info: {page: page, pages: pages}, emails: emails}
      when 'archived'
        users = [user] + user.secondary_users
        user_names = {}
        emails = users.map do |u|
          user_names[u.id] = u.email.gsub!('@gmail.com', '')
          if u.allow_unapproved
            Email.where(user_id: u.id)
              .where(deleted: [false, nil])
              .where(archived: true)
          else
            Email.where(user_id: u.id)
              .where(encrypted_sender: friendly_emails(u))
              .where(deleted: [false, nil])
              .where(archived: true)
          end
        end.flatten.compact.map do |e|
          {
            id: e.id,
            sender: truncate(e.sender),
            subject: CGI.escapeHTML(e.subject),
            date: e.date,
            user: user_names[e.user_id]
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
        pages = (emails.size.to_f / EMAILS_PER_PAGE).ceil
        emails = emails.slice((page - 1) * EMAILS_PER_PAGE, EMAILS_PER_PAGE)
        {info: {page: page, pages: pages}, emails: emails}
      when 'unapproved'
        users = [user] + user.secondary_users
        user_names = {}
        unread = 0
        emails = users.map do |u|
          user_names[u.id] = u.email.gsub!('@gmail.com', '')
          if u.allow_unapproved
            nil
          else
            email_relation = Email.where(user_id: u.id)
                               .where.not(encrypted_sender: friendly_emails(u))
                               .where(sent: false)
                               .where(deleted: [false, nil])
            unread += email_relation.where(unread: true).count
            email_relation
          end
        end.flatten.compact.map do |e|
          {
            id: e.id,
            sender: truncate(e.sender),
            date: e.date,
            unread: e.unread,
            user: user_names[e.user_id]
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
        pages = (emails.size.to_f / EMAILS_PER_PAGE).ceil
        emails = emails.slice((page - 1) * EMAILS_PER_PAGE, EMAILS_PER_PAGE)
        {info: {page: page, pages: pages, unread: unread}, emails: emails}
      else # inbox
        users = [user] + user.secondary_users
        user_names = {}
        unread = 0
        emails = users.map do |u|
          user_names[u.id] = u.email.gsub!('@gmail.com', '')
          if u.allow_unapproved
            email_relation = Email.where(user_id: u.id)
                               .where(archived: false)
                               .where(sent: false)
                               .where(deleted: [false, nil])
            unread += email_relation.where(unread: true).count
            email_relation
          else
            email_relation = Email.where(user_id: u.id)
                               .where(encrypted_sender: friendly_emails(u))
                               .where(archived: false)
                               .where(sent: false)
                               .where(deleted: [false, nil])
            unread += email_relation.where(unread: true).count
            email_relation
          end
        end.flatten.compact.map do |e|
          {
            id: e.id,
            sender: truncate(e.sender),
            subject: CGI.escapeHTML(e.subject),
            date: e.date,
            unread: e.unread,
            user: user_names[e.user_id]
          }
        end.sort { |x, y| y[:date] <=> x[:date] }
        pages = (emails.size.to_f / EMAILS_PER_PAGE).ceil
        emails = emails.slice((page - 1) * EMAILS_PER_PAGE, EMAILS_PER_PAGE)
        {info: {page: page, pages: pages, unread: unread}, emails: emails}
    end
  end

  # wrap http and https urls in <a> tags so the user can click on them
  def linkify_urls(str)
    str.gsub(/(?<url>((?:(http|https|Http|Https|rtsp|Rtsp):\/\/(?:(?:[a-zA-Z0-9\$\-\_\.\+\!\*'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,64}(?:\:(?:[a-zA-Z0-9\$\-\_\.\+\!\*'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,25})?\@)?)?((?:(?:[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}\.)+(?:(?:aero|arpa|asia|a[cdefgilmnoqrstuwxz])|(?:biz|b[abdefghijmnorstvwyz])|(?:cat|com|coop|c[acdfghiklmnoruvxyz])|d[ejkmoz]|(?:edu|e[cegrstu])|f[ijkmor]|(?:gov|g[abdefghilmnpqrstuwy])|h[kmnrtu]|(?:info|int|i[delmnoqrst])|(?:jobs|j[emop])|k[eghimnrwyz]|l[abcikrstuvy]|(?:mil|mobi|museum|m[acdghklmnopqrstuvwxyz])|(?:name|net|n[acefgilopruz])|(?:org|om)|(?:pro|p[aefghklmnrstwy])|qa|r[eouw]|s[abcdeghijklmnortuvyz]|(?:tel|travel|t[cdfghjklmnoprtvwz])|u[agkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw]))|(?:(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9])))(?:\:\d{1,5})?)(\/(?:(?:[a-zA-Z0-9\;\/\?\:\@\&\=\#\~\-\.\+\!\*'\(\)\,\_])|(?:\%[a-fA-F0-9]{2}))*)?)/, '<a href="\k<url>">\k<url></a>')
  end

  def assemble_parts(part, args)
    if part.multipart?
      part.parts.collect { |sub_part| assemble_parts(sub_part, args) }.compact.join('')
    else
      if part.content_type.nil?
        CGI.escapeHTML(part.body.to_s) # Not sure if this really works.  We don't seem to handle non-multipart messages correctly.
      elsif part.content_type.start_with?('text/html') && !args[:text_only]
        nil
      elsif part.content_type.start_with? 'text/plain'
        if :no_links
          CGI.escapeHTML(part.decoded)
        else
          linkify_urls(CGI.escapeHTML(part.decoded))
        end
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
    original_lines = text({text_only: true, no_links: true}).split("\n").collect do |line|
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
