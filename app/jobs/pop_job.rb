class PopJob < ActiveJob::Base
  queue_as :default

  def perform(user)
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
        Email.create(:body => email.to_s, :user_id => user.id, :archived => false, :sent => false)
      end
    end

  end

end
