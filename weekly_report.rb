require "httparty"
require "mail"
require 'dotenv'
require 'json'
require 'cgi'
require 'date'

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

subscribers = JSON.parse(File.read('subscribers.json'))

subscribers.each do |user|

  email = user['email']
  next unless user['locations'].is_a?(Array)

  weekly_locations = user['locations'].select { |l| l['weekly'] }
  next if weekly_locations.empty?

  email_body = ""
  email_body += "<h1>❄️ WEEKLY SKI REPORT ❄️</h1>"

  weekly_locations.each do |location|

    latitude = location['latitude']
    longitude = location['longitude']
    resort_name = location['resort_name']

    location_display =
      if resort_name && !resort_name.strip.empty?
        CGI.escapeHTML(resort_name)
      else
        "#{latitude}, #{longitude}"
      end

    begin
      response = HTTParty.get(
        "https://api.open-meteo.com/v1/forecast",
        query: {
          latitude: latitude,
          longitude: longitude,
          daily: "temperature_2m_max,temperature_2m_min,snowfall_sum,precipitation_probability_max,wind_speed_10m_max",
          timezone: "America/Los_Angeles",
          forecast_days: 7,
          wind_speed_unit: "mph",
          temperature_unit: "fahrenheit",
          precipitation_unit: "inch"
        }
      )
    rescue StandardError => e
      puts "Weather API error for #{location_display}: #{e.message}"
      next
    end

    sleep 0.3

    next unless response&.code == 200
    next unless response['daily']

    daily_units = response['daily_units']
    daily_data = response['daily']

    email_body += "<h2>#{location_display}</h2>"

    daily_data['time'].each_with_index do |date, index|
      email_body += "<h3>#{Date.parse(date).strftime("%A, %m/%d/%Y")}</h3>"
      email_body += "<p>🌡️ High: #{daily_data['temperature_2m_max'][index]}#{daily_units['temperature_2m_max']}</p>"
      email_body += "<p>🧊 Low: #{daily_data['temperature_2m_min'][index]}#{daily_units['temperature_2m_min']}</p>"
      email_body += "<p>❄️ Snowfall: #{daily_data['snowfall_sum'][index]} #{daily_units['snowfall_sum']}</p>"
      email_body += "<hr>"
    end

    # Unsubscribe from THIS location
    single_unsub_weekly =
      "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
      "?email=#{CGI.escape(email)}" \
      "&lat=#{latitude}" \
      "&lon=#{longitude}" \
      "&type=weekly"

    email_body += "<p style='font-size:12px'>"
    email_body += "<a href='#{single_unsub_weekly}'>Unsubscribe from this location</a>"
    email_body += "</p>"
    email_body += "<hr style='margin:25px 0;'>"

  end

  # Global unsubscribe
  all_weekly_unsub =
    "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
    "?email=#{CGI.escape(email)}" \
    "&type=weekly&all=true"

  email_body += "<p style='font-size:12px;color:#999'>"
  email_body += "<a href='#{all_weekly_unsub}'>Unsubscribe from all weekly reports</a>"
  email_body += "</p>"

  Mail.deliver do
    from "deesjaime@gmail.com"
    to email
    subject "Weekly Ski Report"
    content_type 'text/html; charset=UTF-8'
    body email_body
  end

  puts "Weekly email sent to #{email}"

end