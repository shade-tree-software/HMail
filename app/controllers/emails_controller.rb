require 'mail'
require 'userfriend'
require 'friend'

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

  def show
    @email.unread = false
    @email.save
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

  def perform(user_id, count = 5)
    user = User.find(user_id)
    if user.email.end_with? '@gmail.com'
      Email.delete_old_unapproved(user)
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

  def refresh
    perform(current_user.id)
    current_user.secondary_users.each do |secondary_user|
      perform(secondary_user.id, 1)
    end
    render nothing: true
  end

  def refresh_all
    User.all.each do |user|
      unless user.email == 'none@nowhere.com' || user.email == 'guest@nowhere.none'
        perform(user.id, 1)
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
