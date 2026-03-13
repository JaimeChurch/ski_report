require "mail"
require "dotenv"
require "json"
require "cgi"

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


def send_welcome_email(user_email, locations)

  email_body = ""
  email_body += "<h1>🤖 Welcome to SnowBot!</h1>"
  email_body += "<p>You have successfully subscribed to the following reports:</p>"

  locations.each do |location|

    latitude = location['latitude']
    longitude = location['longitude']
    resort_name = location['resort_name']

    location_display =
      if resort_name && !resort_name.strip.empty?
        CGI.escapeHTML(resort_name)
      else
        "#{latitude}, #{longitude}"
      end

    email_body += "<h2>#{location_display}</h2>"
    email_body += "<ul>"

    if location['daily']
      email_body += "<li>📅 Daily Ski Report</li>"
    end

    if location['weekly']
      email_body += "<li>📅 Weekly Ski Report</li>"
    end

    if location['powder_alert']
      email_body += "<li>❄️ Powder Alerts</li>"
      email_body += "<p style='font-size:14px'>"
      email_body += "You will receive a powder alert when forecasted snowfall exceeds <b>6 inches</b>."
      email_body += "</p>"
    end

    email_body += "</ul>"
  end

  email_body += "<hr>"
  email_body += "<p style='font-size:12px;color:#999'>"
  email_body += "You will begin receiving reports based on your selection."
  email_body += "</p>"

  Mail.deliver do
    from "deesjaime@gmail.com"
    to user_email
    subject "Welcome to SnowBot!"
    content_type 'text/html; charset=UTF-8'
    body email_body
  end

  puts "Welcome email sent to #{user_email}"

end