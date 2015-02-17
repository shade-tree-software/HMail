require 'user'

class PopJob < ActiveJob::Base
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    user_name = user.email
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
    mails = Mail.all

    # insert messages into database only if they are unique (sometimes we get duplicates
    # from the pop server)
    if mails
      mails.each do |mail|
        begin
          Email.find_or_create_by(
              user_id: user.id,
              subject: mail.subject,
              to: mail.to.first,
              from: mail.from.first,
              date: mail.date.to_i) do |new_email|
            new_email.body = mail.to_s
            new_email.archived = false
            new_email.sent = mail.from.first == user_name
            new_email.friendly_date = mail.date.to_time.localtime.ctime
            new_email.unread = true
          end
        rescue ActiveRecord::RecordNotUnique
          # find_or_create_by is not atomic.  If we get a RecordNotUnique exception it
          # means another process tried to create the same record at the same time.
          # Just try again, and this time it should find the matching record created
          # by the other process and should not try to create the duplicate.
          retry
        end
      end
    end

  end

end
