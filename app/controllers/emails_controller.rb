require 'mail'

class EmailsController < ApplicationController
  before_action :set_email, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @emails = Email.where(:user_id => current_user.id)
    respond_with(@emails)
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
    a= current_user.email
    b= current_user.email_pw
    Mail.defaults do
      retriever_method :pop3,
                       {:address => "pop.gmail.com",
                        :port => 995,
                        :user_name => a,
                        :password => b,
                        :enable_ssl => true}
    end
    Email.create(:body => Mail.first.to_s, :user_id => current_user.id)
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
