# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

map '/events' do
  run Events
end

map '/' do
  run Eventsource::Application
end
