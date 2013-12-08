require 'sinatra'
require 'twitter'
require 'yaml'
require 'haml'
require 'oauth'
require 'sinatra/session'
require 'json'
require 'open-uri'
require 'sinatra/reloader' if development?

@@config = {}

configure do
  # Create an arraw of Twitter usernames to follow
  @@config['screen_names_to_follow'] = %w[ bensheldon pontythecat ]

  @@config['twitter_consumer_key'] = ENV['TWITTER_CONSUMER_KEY']
  @@config['twitter_consumer_secret'] = ENV['TWITTER_CONSUMER_SECRET']
  @@config['hostname'] = ENV['HOSTNAME']

  set :session_secret, ENV['SESSION_SECRET']
  set :haml, {:format => :html5, :attr_wrapper => '"' }
end

before do
  @user = session[:user]
  @consumer = OAuth::Consumer.new @@config['twitter_consumer_key'], @@config['twitter_consumer_secret'],
    :site => "http://api.twitter.com",
    :scheme => :header

  Twitter.configure do |config|
    config.consumer_key = @@config['twitter_consumer_key']
    config.consumer_secret = @@config['twitter_consumer_secret']

    if @user
      config.oauth_token = session[:oauth_token]
      config.oauth_token_secret = session[:oauth_token_secret]
    end
  end
end

get '/' do
  @to_follow = @@config['screen_names_to_follow']

  haml :index
end

post '/follow' do
  # Follow *everyone*
  begin
    @followed = Twitter.follow @@config['screen_names_to_follow']
  rescue Twitter::Error::ServerError
    # This error will be raised if Twitter is temporarily unavailable.
    retry
  end

  # Make a note of who were already being followed
  @already_following = @@config['screen_names_to_follow'] -  @followed.map { |account| new_follow.screen_name.downcase }

  haml :follow
end

# sekret helper route for testing stuff
post '/unfollow' do
  # UNFOLLOW *everyone*
  begin
    @unfollowed = Twitter.unfollow @@config['screen_names_to_follow']
  rescue Twitter::Error::ServerError
    # This error will be raised if Twitter is temporarily unavailable.
    retry
  end

  haml :index
end

# Login: store the request tokens and send to Twitter
get '/twitter-connect' do
  request_token = @consumer.get_request_token(:oauth_callback => "#{@@config['hostname']}/auth")

  session[:request_token] = request_token
  redirect request_token.authorize_url
end

# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth' do
  # Exchange the request token for an access token.
  request_token = session[:request_token]
  access_token = OAuth::RequestToken.new(@consumer,
    request_token.token,
    request_token.secret
  ).get_access_token(:oauth_verifier => params[:oauth_verifier])

  # add to Twitter client
  Twitter.oauth_token = access_token.token
  Twitter.oauth_token_secret = access_token.secret

  # add to session
  session_start!
  session[:user] = Twitter.verify_credentials.screen_name
  session[:oauth_token] = access_token.token
  session[:oauth_token_secret] = access_token.secret

  redirect '/'
end

get '/logout' do
  session_end!
  redirect '/'
end
