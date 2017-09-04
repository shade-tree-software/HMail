require 'mail'
require 'userfriend'
require 'friend'
require 'queueclassicjob'

class EmailsController < ApplicationController
  skip_before_filter :authenticate_user!, only: [:refresh_all, :auto_refresh]
  before_action :set_email, only: [:show, :edit, :update, :destroy, :archive, :reply]

  def index
    respond_to do |format|
      format.html do
        @users = ([current_user.email] + current_user.secondary_users.map { |s| s.email }).join(', ').gsub('@gmail.com', '')
        @users.count(',') == 1 ? @users.sub!(',', ' and') : @users.sub!(/(.*),/, '\1, and')
      end
      format.json do
        render json: Email.sync_mailbox(current_user, params[:mailbox_type], params[:page])
      end
    end
  end

  def simple
    respond_to do |format|
      format.html do
        @basic_emails = Email.sync_mailbox(current_user, params[:mailbox_type], params[:page])[:emails]
      end
    end
  end

  def show
    @email.unread = false
    @email.save
    respond_to do |format|
      format.html
      format.json { render json: @email }
    end
  end


  def new
    friends = current_user.friends.collect do |friend|
      [friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id, {class: 'emailRecipient'}]
    end
    @params =
        {
            friends: friends,
            recipients: current_user.allow_unapproved? ? '' : [],
            thread_participant_count: 0,
            allow_unapproved: current_user.allow_unapproved
        }
    @email = Email.new
  end

  def reply
    @params = @email.build_reply(current_user)
    @email = Email.new
    render :action => :new
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
    if current_user.allow_unapproved
      recipients = params[:email][:recipients].delete(' ').split(/,|;/)
    else
      # reject any items from the recipients select that are blank,
      # then map the rest to friend email addresses
      recipients = params[:email][:recipients].reject { |r| r.empty? }.map do |recipient|
        Friend.find(recipient.to_i).email
      end
    end
    subj = params[:email][:subject]
    mail = Mail.new do
      to recipients
      from sender
      subject subj
    end

    msg = params[:email][:message]
    text_part = Mail::Part.new do
      body msg
    end
    mail.text_part = text_part

    pic = params[:email][:picture]
    mail.attachments[pic.original_filename] = pic.read if pic

    mail.deliver! unless current_user.email == 'none@nowhere.com'

    @email = Email.new(:body => mail.to_s,
                       :user_id => current_user.id,
                       :archived => false,
                       :sent => true,
                       :recipients => recipients.join(', '),
                       :sender => sender,
                       :subject => subj,
                       :date => mail.date.to_i,
                       :deleted => false)
    @email.save
    redirect_to emails_url
  end

  #def update
  #  @email.update(email_params)
  #  respond_with(@email)
  #end

  def destroy
    @email[:deleted] = true
    @email.save
    redirect_to emails_url
  end

  def archive
    @email.update(:archived => true)
    flash[:notice] = "Message has been archived"
    render :action => :show
  end

  def refresh
    #users_queued = QueueClassicJob.select(:args).collect { |job| job.args[0]['arguments'][0] }
    #PopJob.perform_later(current_user.id) unless users_queued.include? current_user.id
    PopJob.perform_later(current_user.id)
    secondary_users = current_user.secondary_users
    if params[:secondary_users] == 'odd'
      secondary_users = secondary_users.map { |n| n }.select.each_with_index { |_, i| i.odd? }
    elsif params[:secondary_users] == 'even'
      secondary_users = secondary_users.map { |n| n }.select.each_with_index { |_, i| i.even? }
    end
    secondary_users.each do |secondary_user|
      PopJob.perform_later(secondary_user.id, 1)
    end
    render nothing: true
  end

  def refresh_all
    User.all.each do |user|
      unless user.email == 'none@nowhere.com' || user.email == 'guest@nowhere.none'
        PopJob.perform_later(user.id, 1)
      end
    end
    render nothing: true
  end

  def auto_refresh
    @period = params[:period] # minutes
  end

  def image
    original_user_id = Email.find(params[:id]).user_id
    filename = "media/#{original_user_id}_#{params[:id]}_#{params[:filename]}"
    image_data = File.read filename
    File.delete filename
    send_data image_data
  end

  private
  def set_email
    @email = Email.find(params[:id])
  end

  def email_params
    params.require(:email).permit(:body, :user_id)
  end
end
