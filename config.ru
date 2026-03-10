require 'roda'
require 'json'
require './welcome_message.rb'

class App < Roda
  plugin :json_parser
  plugin :all_verbs

  #  Helpers 
  def load_subscribers
    File.write('subscribers.json', '[]') unless File.exist?('subscribers.json')
    JSON.parse(File.read('subscribers.json'))
  end

  def save_subscribers(data)
    File.write('subscribers.json', JSON.pretty_generate(data))
  end

  route do |r|
    #  CORS Headers
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, ngrok-skip-browser-warning'

    r.options do
      response.status = 200
      ""
    end

    # SUBSCRIBE
    r.on 'api' do
      r.on 'subscribers' do
        r.post do
          data = r.POST
          # Validate Email
          email = data['email']&.downcase&.strip
          return { success: false, error: "Invalid email" }.to_json unless email&.include?("@")

          loc = data['locations']&.first
          return { success: false, error: "No location provided" }.to_json unless loc

          lat = loc['latitude'].to_f.round(3)
          lon = loc['longitude'].to_f.round(3)

          # Load Subscribers
          subscribers = load_subscribers
          user = subscribers.find { |s| s['email'] == email }

          new_user = false
          unless user
            user = { 'email' => email, 'locations' => [] }
            subscribers << user
            new_user = true
          end

          user['locations'] ||= []

          # Check if location already exists
          existing = user['locations'].find do |l|
            l['latitude'].to_f.round(3) == lat &&
            l['longitude'].to_f.round(3) == lon
          end

          added_location = nil

          if existing
            # Update subscription types if new
            new_type_added = false
            %w[daily weekly powder_alert].each do |type|
              if loc[type] && !existing[type]
                existing[type] = true
                new_type_added = true
              end
            end

            # Update resort name if provided
            existing['resort_name'] = loc['resort_name'] if loc['resort_name']&.strip&.length&.positive?

            added_location = existing if new_type_added
          else
            # Add new location
            new_location = {
              'latitude' => lat,
              'longitude' => lon,
              'resort_name' => loc['resort_name'],
              'daily' => !!loc['daily'],
              'weekly' => !!loc['weekly'],
              'powder_alert' => !!loc['powder_alert']
            }
            user['locations'] << new_location
            added_location = new_location
          end

          save_subscribers(subscribers)

          # Send welcome email if anything new added
          send_welcome_email(email, [added_location]) if added_location

          { success: true }.to_json
        end
      end
    end

    #  Unsubscribe
    r.on 'unsubscribe' do
      r.get do
        email = r.params['email']&.downcase&.strip
        type = r.params['type']            # daily | weekly | powder_alert
        all = r.params['all']              # true = all locations but ONLY this type

        subscribers = load_subscribers
        user = subscribers.find { |s| s['email'] == email }

        if user && type
          if all
            # Unsubscribe from the given report type for all locations
            user['locations'].each { |loc| loc[type] = false }
          else
            # Unsubscribe from a single location for the given type
            lat = r.params['lat']&.to_f&.round(3)
            lon = r.params['lon']&.to_f&.round(3)

            loc = user['locations'].find do |l|
              l['latitude'].to_f.round(3) == lat &&
              l['longitude'].to_f.round(3) == lon
            end

            loc[type] = false if loc
          end

          # Remove locations with no active subscriptions
          user['locations'].delete_if { |loc| !(loc['daily'] || loc['weekly'] || loc['powder_alert']) }

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