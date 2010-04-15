#!/usr/bin/ruby

require 'open-uri'
require 'base64'

LIGHTS = {:red => 1, :yellow => 2, :green => 3}
STATES = {:on => 1, :off => 0}

URL = ENV['TRAFFICLIGHT_CI_URL'];
CREDENTIALS = ENV['TRAFFICLIGHT_CI_CREDENTIALS'];

@current_state = {}

status_lines = `sispmctl -qng all`

LIGHTS.each_pair do |key, value|
  current_state = 0
  status_lines.each_with_index do |l, i|
    current_state = l if i == value-1
  end
  @current_state[key] = STATES.keys.find{ |k| STATES[k] == current_state.to_i }
end

puts @current_state.inspect

def turn states
  puts states.inspect
  args = []
  states.each_pair do |light, state|
    #puts "Trying #{light} #{state}."

    if @current_state.has_key?(light) && @current_state[light] != state
      args << "-#{state == :on ? 'o' : 'f'} #{LIGHTS[light]}"

      @current_state[light] = state
    end
  end

  `sispmctl #{args.join(" ")}` unless args.empty?
end

begin
  while true do

    begin

      open(URL, "Authorization" => "Basic " << CREDENTIALS) do |page|

        content = page.read
        building = content.include?('Building') || content.include?('Unknown') # || content.include?('CheckingModifications')
        bad = content.include?('Failure') || content.include?('Exception') # || content.include?('Unknown')

        states = STATES.keys
        # turn :red => states[rand(2)], :yellow => states[rand(2)], :green => states[rand(2)]
        turn :red => bad ? :on : :off, :yellow => building ? :on : :off, :green => !(bad || building) ? :on : :off

      end

      sleep 10

    rescue SignalException => e
      turn :red => :off, :yellow => :off, :green => :off
      Process.exit

    rescue
      # $stderr.puts $!
      # $stderr.puts $@

      turn :red => :off, :yellow => :off, :green => :off

      sleep 20
    end

  end

end
