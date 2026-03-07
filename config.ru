require 'roda'
require 'json'
require './welcome_message.rb'

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
          new_user = false

          unless user
            user = { 'email' => email, 'locations' => [] }
            subscribers << user
            new_user = true
          end

          user['locations'] ||= []

          added_locations = []

          locations.each do |loc|
            lat = loc['latitude'].to_f.round(3)
            lon = loc['longitude'].to_f.round(3)

            existing = user['locations'].find do |l|
              l['latitude'].to_f.round(3) == lat &&
              l['longitude'].to_f.round(3) == lon
            end

            if existing
              # Track if any new subscription type was added
              new_type_added = false

              if loc['daily'] && !existing['daily']
                existing['daily'] = true
                new_type_added = true
              end

              if loc['weekly'] && !existing['weekly']
                existing['weekly'] = true
                new_type_added = true
              end

              if loc['powder_alert'] && !existing['powder_alert']
                existing['powder_alert'] = true
                new_type_added = true
              end

              if new_type_added
                added_locations << existing
              end

              if loc['resort_name'] && !loc['resort_name'].strip.empty?
                existing['resort_name'] = loc['resort_name']
              end

            else
              new_location = {
                'latitude' => lat,
                'longitude' => lon,
                'resort_name' => loc['resort_name'],
                'daily' => !!loc['daily'],
                'weekly' => !!loc['weekly'],
                'powder_alert' => !!loc['powder_alert']
              }

              user['locations'] << new_location
              added_locations << new_location
            end
          end

          save_subscribers(subscribers)

          # ---- SEND WELCOME EMAIL ONLY IF NEW SUBSCRIPTION ----
          if added_locations.any?
            require_relative './welcome_message'
            send_welcome_email(email, added_locations)
          end

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