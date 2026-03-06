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

    # ---- SUBSCRIBE ----
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
              'daily' => loc['daily'] || false,
              'weekly' => loc['weekly'] || false,
              'powder_alert' => loc['powder_alert'] || false
            }
          end

          if user
            user['locations'] ||= []

            normalized_locations.each do |new_loc|
              existing_loc = user['locations'].find do |existing|
                existing['latitude'].to_f.round(3) == new_loc['latitude'] &&
                existing['longitude'].to_f.round(3) == new_loc['longitude']
              end

              if existing_loc
                # Merge report types
                existing_loc['daily'] ||= new_loc['daily']
                existing_loc['weekly'] ||= new_loc['weekly']
                existing_loc['powder_alert'] ||= new_loc['powder_alert']

                # Update resort name if provided
                existing_loc['resort_name'] = new_loc['resort_name'] if new_loc['resort_name'] && !new_loc['resort_name'].strip.empty?
              else
                # Add new location
                user['locations'] << new_loc
              end
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

        email = r.params['email']&.downcase&.strip
        type = r.params['type']            # daily | weekly | powder_alert
        all = r.params['all']              # true = all locations but ONLY this type

        subscribers = load_subscribers
        user = subscribers.find { |s| s['email'] == email }

        if user && type

          # Make sure locations exist
          user['locations'] ||= []

          # Unsubscribe logic
          user['locations'].each do |loc|

            if all
              # Remove this report type from ALL locations
              loc[type] = false

            else
              # Remove this report type ONLY for matching location
              lat = r.params['lat']&.to_f&.round(3)
              lon = r.params['lon']&.to_f&.round(3)

              if loc['latitude'].to_f.round(3) == lat &&
                loc['longitude'].to_f.round(3) == lon

                loc[type] = false
              end
            end

          end

          # Remove locations that have NO active subscriptions left
          user['locations'].delete_if do |loc|
            !(loc['daily'] || loc['weekly'] || loc['powder_alert'])
          end

          # Remove user if they have no locations left
          subscribers.delete(user) if user['locations'].empty?

          save_subscribers(subscribers)
        end

        "You have been unsubscribed."
      end
    end

  end
end

run App.freeze.app