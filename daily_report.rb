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

subscribers = JSON.parse(File.read('subscribers.json'))

subscribers.each do |user|
  email = user['email']

  user['locations'].each do |location|
    next unless location['daily']
  
    latitude = location['latitude']
    longitude = location['longitude']
    resort_name = location['resort_name']
  
    location_display =
      if resort_name && resort_name.strip != ""
        resort_name
      else
        "#{latitude}, #{longitude}"
      end

    response = HTTParty.get("https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&daily=temperature_2m_max,temperature_2m_min,uv_index_max,snowfall_sum,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max&timezone=America%2FLos_Angeles&forecast_days=1&wind_speed_unit=mph&temperature_unit=fahrenheit&precipitation_unit=inch") 

    elevation = response['elevation'] * 3.28084
    daily_units = response['daily_units']
    daily_data = response['daily']

    email_body = ""
    email_body += "<h1>❄️ DAILY SKI REPORT ❄️</h1>"
    email_body += "<h2>Location: #{location_display}</h2>\n"
    email_body += "<h2>Today's Forecast:</h2>\n"

    daily_data['time'].each_with_index do |date, index|
        email_body += "<h3>#{Date.parse(date).strftime("%A, %m/%d/%Y")}</h3>\n"
        email_body += "<p><b>🌡️ High Temp: </b>#{daily_data['temperature_2m_max'][index]}#{daily_units['temperature_2m_max']}</p>\n"
        email_body += "<p><b>🧊 Low Temp: </b>#{daily_data['temperature_2m_min'][index]}#{daily_units['temperature_2m_min']}</p>\n"
        email_body += "<p><b>💧 Precipitation: </b>#{daily_data['precipitation_sum'][index]} #{daily_units['precipitation_sum']}</p>\n"
        email_body += "<p><b>❄️ Snowfall: </b>#{daily_data['snowfall_sum'][index]} #{daily_units['snowfall_sum']}</p>\n"
        email_body += "<p><b>🌨️ Precip Chance: </b>#{daily_data['precipitation_probability_max'][index]}#{daily_units['precipitation_probability_max']}</p>\n"
        email_body += "<p><b>💨 Wind Speed: </b>#{daily_data['wind_speed_10m_max'][index]} #{daily_units['wind_speed_10m_max']}</p>\n"
        email_body += "<p><b>🌬️ Wind Gust: </b>#{daily_data['wind_gusts_10m_max'][index]} #{daily_units['wind_gusts_10m_max']}</p>\n"
        email_body += "<p><b>☀️ UV Index: </b>#{daily_data['uv_index_max'][index]}</p>\n"
    end

  email_body += "<hr style='margin-top: 30px; margin-bottom: 20px;'>"
  single_unsub = "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe?email=#{CGI.escape(email)}&lat=#{latitude}&lon=#{longitude}"
  all_unsub = "https://demetrius-sugared-superevangelically.ngrok-free.dev/unsubscribe?email=#{CGI.escape(email)}&all=true"

  email_body += "<p style='font-size: 12px; color: #999;'>"
  email_body += "Don't want these emails?<br>"
  email_body += "<a href='#{single_unsub}'>Unsubscribe from this location</a><br>"
  email_body += "<a href='#{all_unsub}'>Unsubscribe from ALL locations</a><br>"
  email_body += "</p>"

  Mail.deliver do
    from "deesjaime@gmail.com"
    to email
    subject "Daily Ski Report — #{location_display}"    
    content_type 'text/html; charset=UTF-8'
    body email_body
  end

  puts "Email sent to #{email}"
end
end