require "httparty"
require "dotenv/load"

response = HTTParty.get("https://api.openweathermap.org/geo/1.0/direct?q=bremerton,wa,us&limit=1&appid=#{ENV["API_KEY"]}") 
# response = HTTParty.get("https://api.openweathermap.org/data/2.5/weather?lat=47.5&lon=-122.6&appid=#{ENV["API_KEY2"]}") 

puts response