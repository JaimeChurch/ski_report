require 'sinatra'
require 'json'

set :port, 4567
set :bind, '0.0.0.0'

# Disable Rack protection for ngrok
disable :protection

# Enable CORS
before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '*' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  200
end

# Initialize file
File.write('subscribers.json', '[]') unless File.exist?('subscribers.json')

# Save subscriber
post '/api/subscribers' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  subscribers = JSON.parse(File.read('subscribers.json'))
  
  # Check if email exists
  return { error: 'Already subscribed' }.to_json if subscribers.any? { |s| s['email'] == data['email'] }
  
  # Add subscriber
  subscribers << {
    email: data['email'],
    latitude: data['latitude'].to_f.round(2),
    longitude: data['longitude'].to_f.round(2),
    daily: data['daily'],
    weekly: data['weekly']
  }
  
  File.write('subscribers.json', JSON.pretty_generate(subscribers))
  { success: true }.to_json
end

# Unsubscribe link
get '/unsubscribe' do
  email = params[:email]
  subscribers = JSON.parse(File.read('subscribers.json'))
  
  subscribers.delete_if { |s| s['email'] == email }
  File.write('subscribers.json', JSON.pretty_generate(subscribers))
  
  "You have been unsubscribed. <a href='javascript:history.back()'>Go back</a>"
end