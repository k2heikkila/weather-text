require 'forecast_io'
require 'json'
require 'twilio-ruby'
require "tzinfo"
require 'yaml'

class Runner

  def initialize(config)
    @@config = config
  end

  def get_last_message()
    if @last_message.nil? || refresh_message?
      puts "Refreshing Message..."
      twilio_client = Twilio::REST::Client.new @@config['twilio_account_sid'], @@config['twilio_auth_token']
      @last_message = twilio_client.messages.list.first
    end
    {message:@last_message.body.strip(), time: Time.now}
  end

  def refresh_message?
    if (@last_update_t.nil? || @last_update_t + (2*60) < Time.now)
      @last_update_t = Time.now
    else
      false
    end
  end

  def get_forecast()
    if @forecast_1.nil? || @forecast_2.nil? || refresh_forecast?
      puts "Refreshing forecast..."
      ForecastIO.api_key = @@config['forecast_api_key']
      @forecast_1 = ForecastIO.forecast(@@config['lat_1'], @@config['lon_1'])
      @forecast_2 = ForecastIO.forecast(@@config['lat_2'], @@config['lon_2'])
    end
    [@forecast_1, @forecast_2]
  end

  def refresh_forecast?
    if (@last_update_f.nil? || @last_update_f + (15*60) < Time.now)
      @last_update_f = Time.now
    else
      false
    end
  end

  def run
    loop do
      forecast = get_forecast()
      tz = TZInfo::Timezone.get(forecast[0]['timezone'])
      time = tz.utc_to_local(Time.now.utc)
      last_message= get_last_message();
      print '.'
      data = {
        city1:          @@config['city_1'],
        city1Timezone:  forecast[0]['timezone'],
        city2:          @@config['city_2'],
        city2Timezone:  forecast[1]['timezone'],
        city1Icon:      forecast[0]['currently']['icon'],
        city2Icon:      forecast[1]['currently']['icon'],
        city1Summary:   forecast[0]['currently']['summary'],
        city2Summary:   forecast[1]['currently']['summary'],
        city1Temp:      forecast[0]['currently']['temperature'],
        city2Temp:      forecast[1]['currently']['temperature'],
        city1Low:       forecast[0]['daily']['data'][0]['temperatureMin'],
        city2Low:       forecast[1]['daily']['data'][0]['temperatureMin'],
        city1High:      forecast[0]['daily']['data'][0]['temperatureMax'],
        city2High:      forecast[1]['daily']['data'][0]['temperatureMax'],
        date:           time.strftime("%B %e").strip(),
        time:           time.strftime("%l:%M %p").strip(),
        lastText:       last_message[:message],
        lastTextTime:   last_message[:time]
      }

      path = File.join(File.dirname(__FILE__),"view/data.json")
      File.open(path, 'w+') { |file|
        file.write (data.to_json)
      }
      sleep 5
    end
  end
end

cnf = YAML::load_file(File.join(__dir__, 'config.yml'))
runner = Runner.new(cnf)
runner.run()
