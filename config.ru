require 'roda'
require 'json'

class App < Roda
  plugin :json_parser
  plugin :all_verbs

  route do |r|

    # ---- CORS ----
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'

    r.options do
      response.status = 200
      ""
    end

    # ---- Helpers ----
    def load_subscribers
      File.write('subscribers.json', '[]') unless File.exist?('subscribers.json')
      JSON.parse(File.read('subscribers.json'))
    end

    def save_subscribers(data)
      File.write('subscribers.json', JSON.pretty_generate(data))
    end

    # ---- API ----
    r.on 'api' do
      r.on 'subscribers' do
        r.post do
          data = r.params

          lat = data['latitude'].to_f.round(3)
          lon = data['longitude'].to_f.round(3)

          subscribers = load_subscribers
          user = subscribers.find { |s| s['email'] == data['email'] }

          if user
            if user['locations'].any? { |l| l['latitude'] == lat && l['longitude'] == lon }
              next { error: 'Already subscribed to this location' }.to_json
            end

            user['locations'] << {
              latitude: lat,
              longitude: lon,
              daily: data['daily'],
              weekly: data['weekly']
            }

          else
            subscribers << {
              email: data['email'],
              locations: [
                {
                  latitude: lat,
                  longitude: lon,
                  daily: data['daily'],
                  weekly: data['weekly']
                }
              ]
            }
          end

          save_subscribers(subscribers)
          { success: true }.to_json
        end
      end
    end

# ---- Unsubscribe ----
r.on 'unsubscribe' do
  r.get do
    email = r.params['email']
    all = r.params['all']

    subscribers = load_subscribers
    user = subscribers.find { |s| s['email'] == email }

    if user
      if all
        # Remove entire user
        subscribers.delete(user)
      else
        lat = r.params['lat']&.to_f
        lon = r.params['lon']&.to_f

        user['locations'].delete_if do |loc|
          loc['latitude'] == lat && loc['longitude'] == lon
        end

        # Remove user if no locations remain
        subscribers.delete(user) if user['locations'].empty?
      end

      save_subscribers(subscribers)
    end

    "You have been unsubscribed."
  end
end

run App.freeze.app