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

    emails = Mail.all
    if emails
      emails.each do |email|
        args = {}
        args[:body] = email.to_s
        args[:user_id] = user.id
        args[:archived] = false
        args[:subject] = email.subject
        args[:to] = email.to.first
        args[:from] = email.from.first
        args[:sent] = args[:from] == user_name
        args[:date] = email.date.to_i
        args[:friendly_date] = email.date.to_time.localtime.ctime
        Email.create(args)
      end
    end

  end

end
