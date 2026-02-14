require 'roda'
require 'json'

class App < Roda
  plugin :json_parser
  plugin :all_verbs

  route do |r|
    # Handle OPTIONS preflight at the top level
    if r.options?
      response['Access-Control-Allow-Origin'] = '*'
      response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
      response['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'
      response.status = 200
      return ""
    end

    # CORS headers for all requests
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'

    r.on 'api' do
      r.on 'subscribers' do
        r.post do
          puts "POST received!"
          
          data = JSON.parse(request.body.read)
          puts "Data: #{data.inspect}"
          
          File.write('subscribers.json', '[]') unless File.exist?('subscribers.json')
          subscribers = JSON.parse(File.read('subscribers.json'))
          
          return { error: 'Already subscribed' }.to_json if subscribers.any? { |s| s['email'] == data['email'] }
          
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
      end
    end

    r.on 'unsubscribe' do
      r.get do
        email = r.params['email']
        subscribers = JSON.parse(File.read('subscribers.json'))
        subscribers.delete_if { |s| s['email'] == email }
        File.write('subscribers.json', JSON.pretty_generate(subscribers))
        "You have been unsubscribed."
      end
    end
  end
end

run App.freeze.app