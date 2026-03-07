require "httparty"
require "mail"
require 'dotenv'
require 'json'
require 'cgi'

Dotenv.load('api_key.env')

Mail.defaults do
  delivery_method :smtp, {
    address: "smtp.gmail.com",
    port: 587,
    user_name: "deesjaime@gmail.com",
    password: ENV["APP_PW"],
    authentication: "plain",
    enable_starttls_auto: true
  }
end

THRESHOLD = 6

subscribers = JSON.parse(File.read('subscribers.json'))

subscribers.each do |user|

  email = user['email']
  next unless user['locations'].is_a?(Array)

  powder_matches = []

  user['locations'].each do |location|

    next unless location['powder_alert'] == true

    latitude = location['latitude']
    longitude = location['longitude']
    resort_name = location['resort_name']

    location_display =
      if resort_name && !resort_name.strip.empty?
        resort_name
      else
        "#{latitude}, #{longitude}"
      end

    response = HTTParty.get(
      "https://api.open-meteo.com/v1/forecast",
      query: {
        latitude: latitude,
        longitude: longitude,
        daily: "snowfall_sum",
        timezone: "America/Los_Angeles",
        forecast_days: 1,
        precipitation_unit: "inch"
      }
    )

    next unless response&.code == 200
    next unless response['daily']

    snowfall = response['daily']['snowfall_sum'][0].to_f

    # Only store locations that match
    if snowfall >= THRESHOLD
      powder_matches << {
        display: location_display,
        snowfall: snowfall,
        lat: latitude,
        lon: longitude
      }
    end
  end

  # Skip if no matches
  next if powder_matches.empty?

  #Email
  email_body = ""
  email_body += "<h1>❄️ POWDER ALERT ❄️</h1>"

  powder_matches.each do |match|
    email_body += "<h2>#{match[:display]}</h2>"
    email_body += "<p>❄️ Expected Snowfall: #{match[:snowfall]} inches</p>"

    single_unsub =
      "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
      "?email=#{CGI.escape(email)}" \
      "&lat=#{match[:lat]}" \
      "&lon=#{match[:lon]}" \
      "&type=powder_alert"

    email_body += "<p style='font-size:12px'>"
    email_body += "<a href='#{single_unsub}'>Unsubscribe from powder alerts for this location</a>"
    email_body += "</p>"
    email_body += "<hr>"
  end

  all_unsub =
    "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
    "?email=#{CGI.escape(email)}" \
    "&type=powder_alert&all=true"

  email_body += "<hr style='margin-top:30px;margin-bottom:20px;'>"
  email_body += "<p style='font-size:12px;color:#999'>"
  email_body += "<a href='#{all_unsub}'>Unsubscribe from all powder alerts</a>"
  email_body += "</p>"

  Mail.deliver do
    from "deesjaime@gmail.com"
    to email
    subject "Powder Alert! ❄️"
    content_type 'text/html; charset=UTF-8'
    body email_body
  end

  puts "Powder alert sent to #{email}"

end