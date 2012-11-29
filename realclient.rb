# coding: utf-8
require 'json'
require 'oauth2'
require 'sinatra'

# Load custom environment variables
load 'env.rb' if File.exists?('env.rb')

enable :sessions

helpers do
  def signed_in?
    !session[:access_token].nil?
  end

  def sexy_json(json)
    JSON.pretty_generate(json)
  end
end

def redirect_uri
  ENV['OAUTH2_CLIENT_REDIRECT_URI']
end

def client(token_method = :post)
  OAuth2::Client.new(
    ENV['OAUTH2_CLIENT_ID'],
    ENV['OAUTH2_CLIENT_SECRET'],
    site:         ENV['SITE'] || 'http://localhost:3000',
    token_method: token_method
  )
end

def access_token
  OAuth2::AccessToken.new(client, session[:access_token], refresh_token: session[:refresh_token])
end

get '/' do
  erb :home
end

get '/login' do
  scope = params[:scope] || 'public'
  redirect client.auth_code.authorize_url(redirect_uri: redirect_uri, scope: scope)
end

get '/logout' do
  session[:access_token] = nil
  redirect '/'
end

get '/refresh_token' do
  new_token = access_token.refresh!
  session[:access_token]  = new_token.token
  session[:refresh_token] = new_token.refresh_token
  redirect '/'
end

get '/callback' do
  new_token = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
  session[:access_token]  = new_token.token
  session[:refresh_token] = new_token.refresh_token
  redirect '/'
end

get '/realguard/:api' do
  raise 'please provide an endpoint' unless params[:api]

  begin
    response = access_token.get("/api/#{params[:api]}")
    @json = JSON.parse(response.body)
    erb :realguard, layout: !request.xhr?
  rescue OAuth2::Error => @error
    erb :error, layout: !request.xhr?
  end
end

__END__

@@ layout
<html>
  <head>
    <title>Super Simple Realguard Client</title>
    <meta charset="utf-8" />
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>
  </head>
  <body><%= yield %></body>
</html>


@@ home
<% if signed_in? %>
  <a href='/realguard/users.json' target='_self'>list all users</a>
  <p>Your access token: <code><%= session[:access_token] %></code> (<a href="/refresh_token" target='_self' title="<%= session[:refresh_token] %>">refresh</a>)</p>
  <a href='/logout' target='_self'>Log me out</a>
<% else %>
  <a href='/login' target='_self'>Login to realguard</a>
<% end %>

@@ realguard
<%= sexy_json @json %>

@@ error
<p><code>OAuth2::Error</code></p>
<%= @error.response.inspect %>

