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

  email_body = ""
  email_body += "<h1>❄️ DAILY SKI REPORT ❄️</h1>"

  user['locations'].each do |location|

    next unless location['daily'] == true

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
        daily: "temperature_2m_max,temperature_2m_min,uv_index_max,snowfall_sum,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max",
        timezone: "America/Los_Angeles",
        forecast_days: 1,
        wind_speed_unit: "mph",
        temperature_unit: "fahrenheit",
        precipitation_unit: "inch"
      }
    )

    next unless response && response['daily']

    daily_units = response['daily_units']
    daily_data = response['daily']

    email_body += "<h2>Location: #{location_display}</h2>"

    daily_data['time'].each_with_index do |date, index|

      email_body += "<h3>#{Date.parse(date).strftime("%A, %m/%d/%Y")}</h3>"
      email_body += "<p>🌡️ High: #{daily_data['temperature_2m_max'][index]}#{daily_units['temperature_2m_max']}</p>"
      email_body += "<p>🧊 Low: #{daily_data['temperature_2m_min'][index]}#{daily_units['temperature_2m_min']}</p>"
      email_body += "<p>❄️ Snowfall: #{daily_data['snowfall_sum'][index]} #{daily_units['snowfall_sum']}</p>"
      email_body += "<p>🌨️ Precip Chance: #{daily_data['precipitation_probability_max'][index]}#{daily_units['precipitation_probability_max']}</p>"
      email_body += "<p>💨 Wind Speed: #{daily_data['wind_speed_10m_max'][index]} #{daily_units['wind_speed_10m_max']}</p>"

      # Location unsubscribe link
      single_unsub_daily =
        "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
        "?email=#{CGI.escape(email)}" \
        "&lat=#{latitude}" \
        "&lon=#{longitude}" \
        "&type=daily"

      email_body += "<p style='font-size:12px'>"
      email_body += "<a href='#{single_unsub_daily}'>Unsubscribe from this location</a>"
      email_body += "</p>"

      email_body += "<hr>"
    end
  end

  # Global unsubscribe footer
  all_daily_unsub =
    "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe" \
    "?email=#{CGI.escape(email)}" \
    "&type=daily" \
    "&all=true"

  email_body += "<hr style='margin-top:30px;margin-bottom:20px;'>"
  email_body += "<p style='font-size:12px;color:#999'>"
  email_body += "<a href='#{all_daily_unsub}'>Unsubscribe from all daily reports</a>"
  email_body += "</p>"

  Mail.deliver do
    from "deesjaime@gmail.com"
    to email
    subject "Daily Ski Report"
    content_type 'text/html; charset=UTF-8'
    body email_body
  end

  puts "Daily email sent to #{email}"

end