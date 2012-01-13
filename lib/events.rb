require 'sinatra'
require 'eventmachine'

class Connection
  include EM::Deferrable
  
  def send(data, id=nil)
    data.each_line{|line| output data_line(line) }
    output id_line(id) if id
    output end_message_line
  end
  
  def each(&block)
    @body_callback = block
  end
  
  def close
    succeed
  end
  
  private
  
  def output(string)
    @body_callback.call string
  end
  
  def data_line(line)
    "data: #{line.strip}\n"
  end
  
  def id_line(id)
    "id: #{id}\n"
  end
  
  def end_message_line
    "\n"
  end
  
end

class Events < Sinatra::Base

  connections = []

  get '/test' do
    content_type :html
    File.read File.expand_path('../../app/views/home/index.html', __FILE__)
  end

  # The long streaming request
  get '/' do
    c = Connection.new
    connections << c
    env['async.callback'].call [200, {'Content-Type' => 'text/event-stream'}, c]
    EM::PeriodicTimer.new(1) do
      c.send("some data")
    end
    throw :async
  end
  
  post '/' do
    connections.each do |s|
      puts "Sending message #{params[:message]}"
      s.send params[:message]
    end
  end
  
  delete '/' do
    connections.each do |s|
      s.send "Slater"
      s.close
    end
  end

end
