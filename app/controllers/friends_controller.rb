class FriendsController < ApplicationController
  before_action :set_friend, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @friends = Friend.all
    respond_with(@fiends)
  end

  def show
    respond_with(@friend)
  end

  def new
    @friend = Friend.new
    respond_with(@friend)
  end

  def edit
  end

  def create
    @friend = Friend.new(friend_params)
    @friend.save
    respond_with(@friend)
  end

  def update
    @friend.update(email_params)
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
