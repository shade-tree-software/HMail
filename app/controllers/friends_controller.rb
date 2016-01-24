require 'user'

class FriendsController < ApplicationController
  before_action :set_friend, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @friends = Friend.all
    respond_with(@friends)
  end

  #def show
  #  respond_with(@friend)
  #end

  def new
    @friend = Friend.new
    users = User.all.map { |user| [user.email, user.id] }
    @params = {all_users: users, user_friends: []}
    respond_with(@friend)
  end

  def edit
    users = User.all.map { |user| [user.email, user.id] }
    user_friends = @friend.users.map { |user_friend| user_friend.id }
    @params = {all_users: users, user_friends: user_friends}
  end

  def create
    @friend = Friend.new(friend_params)
    @friend.save
    user_ids = params[:friend][:users].reject {|user_id| user_id.empty?}
    users = user_ids.map {|user_id| User.find(user_id)}
    @friend.users = users
    respond_with(@friend)
  end

  def update
    @friend.update(friend_params)
    user_ids = params[:friend][:users].reject {|user_id| user_id.empty?}
    users = user_ids.map {|user_id| User.find(user_id)}
    @friend.users = users
    respond_with(@friend)
  end

  def destroy
    @friend.destroy
    respond_with(@friend)
  end

  private
  def set_friend
    @friend = Friend.find(params[:id])
  end

  def friend_params
    params.require(:friend).permit(:first_name, :last_name, :email)
  end
end
