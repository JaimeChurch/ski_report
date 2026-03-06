require 'roda'
require 'json'

class App < Roda
  plugin :json_parser
  plugin :all_verbs

  # ---- Helpers ----
  def load_subscribers
    File.write('subscribers.json', '[]') unless File.exist?('subscribers.json')
    JSON.parse(File.read('subscribers.json'))
  end

  def save_subscribers(data)
    File.write('subscribers.json', JSON.pretty_generate(data))
  end

  route do |r|

    # ---- CORS ----
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'

    r.options do
      response.status = 200
      ""
    end

    # ---- API ----
    r.on 'api' do
      r.on 'subscribers' do
        r.post do

          data = r.POST

          email = data['email']&.downcase&.strip
          return { success: false, error: "Invalid email" }.to_json unless email&.include?("@")

          locations = data['locations'] || []

          subscribers = load_subscribers
          user = subscribers.find { |s| s['email'] == email }

          normalized_locations = locations.map do |loc|
            {
              'latitude' => loc['latitude'].to_f.round(3),
              'longitude' => loc['longitude'].to_f.round(3),
              'resort_name' => loc['resort_name'],
              'daily' => loc['daily'],
              'weekly' => loc['weekly']
            }
          end

          if user
            user['locations'] ||= []

            normalized_locations.each do |new_loc|
              exists = user['locations'].any? do |existing|
                existing['latitude'] == new_loc['latitude'] &&
                existing['longitude'] == new_loc['longitude']
              end

              # Append only if not already subscribed to that location
              user['locations'] << new_loc unless exists
            end

          else
            subscribers << {
              'email' => email,
              'locations' => normalized_locations
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
            subscribers.delete(user)
          else
            lat = r.params['lat']&.to_f
            lon = r.params['lon']&.to_f

            (user['locations'] || []).delete_if do |loc|
              loc['latitude'] == lat && loc['longitude'] == lon
            end

            subscribers.delete(user) if user['locations'].empty?
          end

          save_subscribers(subscribers)
        end

        "You have been unsubscribed."
      end
    end

  end
end

run App.freeze.app