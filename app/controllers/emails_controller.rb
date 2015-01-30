require 'mail'
require 'userfriend'
require 'friend'

class EmailsController < ApplicationController
  before_action :set_email, only: [:show, :edit, :update, :destroy, :archive]

  respond_to :html

  def index
    my_emails = Email.where(:user_id => current_user.id)
    friends = current_user.friends.collect { |friend| friend.email }
    inbox = []
    archived = []
    unknown = []
    sent = []
    my_emails.each do |email|
      if email.sent
        sent << email
      else
        if email.from.in? friends
          if email.archived
            archived << email
          else
            inbox << email
          end
        else
          unknown << email
        end
      end
    end
    @emails = {:inbox => inbox, :archived => archived, :unknown => unknown, :sent => sent}
    respond_with(my_emails)
  end

  def show
    respond_with(@email)
  end

  def new
    @friends = current_user.friends.collect do |friend|
      [friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id]
    end
    @email = Email.new
    respond_with(@email)
  end

  #def edit
  #end

  def create
    sender = current_user.email
    password = current_user.email_pw
    Mail.defaults do
      delivery_method :smtp, {:address => "smtp.gmail.com",
                              :port => 587,
                              #:domain => 'your.host.name',
                              :user_name => sender,
                              :password => password,
                              :authentication => 'plain',
                              :enable_starttls_auto => true}
    end
    recipient = Friend.find(params[:email][:to].to_i).email
    subj = params[:email][:subject]
    msg = params[:email][:message]
    mail = Mail.new do
      to recipient
      from sender
      subject subj
      body msg
    end

    mail.deliver!

    @email = Email.new(:body => mail.to_s, :user_id => current_user.id, :archived => false, :sent => true)
    @email.save
    respond_with(@email)
  end

  #def update
  #  @email.update(email_params)
  #  respond_with(@email)
  #end

  #def destroy
  #  @email.destroy
  #  respond_with(@email)
  #end

  def archive
    @email.update(:archived => true)
    redirect_to :action => :index
  end

  def refresh
    user_name = current_user.email
    password = current_user.email_pw
    Mail.defaults do
      retriever_method :pop3,
                       {:address => "pop.gmail.com",
                        :port => 995,
                        :user_name => user_name,
                        :password => password,
                        :enable_ssl => true}
    end
    #emails = [Mail.last]
    emails = Mail.all
    emails.each do |email|
      Email.create(:body => email.to_s, :user_id => current_user.id, :archived => false, :sent => false)
    end
    redirect_to :action => :index
  end

  private
  def set_email
    @email = Email.find(params[:id])
  end

  def email_params
    params.require(:email).permit(:body, :user_id)
  end
end
