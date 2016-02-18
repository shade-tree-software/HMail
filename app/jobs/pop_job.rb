require 'user'

class PopJob < ActiveJob::Base
  queue_as :default

  def perform(user_id, count = 5)
    user = User.find(user_id)
    if user.email.end_with? '@gmail.com'
      user_name = user.email
      puts "Performing PopJob on user_id(#{user_id}), requesting #{count} #{'email'.pluralize(count)}."
      password = user.email_pw
      Mail.defaults do
        retriever_method :pop3,
                         {:address => "pop.gmail.com",
                          :port => 995,
                          :user_name => user_name,
                          :password => password,
                          :enable_ssl => true}
      end

      # get mail messages from pop server
      mails = Mail.last(:count => count)
      #mails = Mail.all

      # insert messages into database only if they are unique (sometimes we get duplicates
      # from the pop server)
      if mails
        mails = [mails] unless mails.is_a? Array
        mails.each do |mail|
          begin
            subject = mail.subject || '(no subject)'
            recipients = ((mail.to || []) + (mail.cc || [])).join(', ')
            sender = mail.from.first
            if ENV['ENCRYPT_EMAIL_DATA'] == 'true'
              subject = Email.encrypt_subject(subject)
              recipients = Email.encrypt_recipients(recipients)
              sender = Email.encrypt_sender(sender)
            end
            Email.find_or_create_by(
                user_id: user.id,
                encrypted_subject: subject,
                encrypted_recipients: recipients,
                encrypted_sender: sender,
                date: mail.date.to_i) do |new_email|
              new_email.body = mail.to_s
              new_email.archived = false
              new_email.sent = (mail.from.first.end_with?('@gmail.com') && (mail.from.first.delete('.') == user_name.delete('.')))
              new_email.unread = true
              new_email.deleted = false
            end
          rescue ActiveRecord::RecordNotUnique
            # find_or_create_by is not atomic.  If we get a RecordNotUnique exception it
            # means another process tried to create the same record at the same time.
            # Just try again, and this time it should find the matching record created
            # by the other process and should not try to create the duplicate.
            retry
          rescue StandardError => e
            puts 'Failed to store retrieved email.  ' + e.message
          rescue Exception => e
            puts 'Failed to store retrieved email.  ' + e.message
            raise e
          end
        end
      end
    else
      puts "PopJob is ignoring user_id(#{user_id}) because it is not a gmail account"
    end
  end

end
