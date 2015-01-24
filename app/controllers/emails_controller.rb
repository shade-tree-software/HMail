require 'mail'

class EmailsController < ApplicationController
  before_action :set_email, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    my_emails = Email.where(:user_id => current_user.id)
    friends = Friend.all.collect { |friend| friend.email }
    inbox = []
    unknown = []
    my_emails.each do |email|
      if email.from.in? friends
        inbox << email
      else
        unknown << email
      end
    end
    @emails = {:inbox => inbox, :unknown => unknown}
    respond_with(my_emails)
  end

  def show
    respond_with(@email)
  end

  def new
    @email = Email.new
    respond_with(@email)
  end

  def edit
  end

  def create
    @email = Email.new(email_params)
    @email.save
    respond_with(@email)
  end

  def update
    @email.update(email_params)
    respond_with(@email)
  end

  def destroy
    @email.destroy
    respond_with(@email)
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
    emails = [Mail.last]
    #emails = Mail.all
    emails.each do |email|
      Email.create(:body => email.to_s, :user_id => current_user.id)
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
