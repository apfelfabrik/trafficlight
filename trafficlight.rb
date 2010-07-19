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

puts "Current state: #{@current_state.inspect}"

def turn states
  args = []
  states.each_pair do |light, state|

    if @current_state.has_key?(light) && @current_state[light] != state
      args << "-#{state == :on ? 'o' : 'f'} #{LIGHTS[light]}"

      @current_state[light] = state
    end
  end

  unless args.empty?
    puts "Changing to: #{states.inspect}"
    `sispmctl #{args.join(" ")}`
  end
end

begin
  while true do

    begin

      open(URL, "Authorization" => "Basic " << CREDENTIALS) do |page|

        content = page.read

        # building and broken are defined states, unknown does not translate to
        # a trafficlight state yet. it might translate to a flashing light once
        # there is support for that.

        building = content.include?('Building') || content.include?('Unknown')
        broken = content.include?('Failure') || content.include?('Exception')
        unknown = content.include?('CheckingModifications') || content.include?('Unknown')

        states = STATES.keys
        # turn :red => states[rand(2)], :yellow => states[rand(2)], :green => states[rand(2)]
        turn :red => broken ? :on : :off, :yellow => building ? :on : :off, :green => !(broken || building) ? :on : :off

      end

      sleep 10

    rescue SignalException => e
      turn :red => :off, :yellow => :off, :green => :off
      Process.exit

    rescue
      puts "Error: #$!"
      $stderr.puts $@

      turn :red => :off, :yellow => :off, :green => :off

      sleep 20
    end

  end

end
