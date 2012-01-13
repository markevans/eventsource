require 'sinatra'

class Subscription
  include EM::Deferrable
  
  def send(data, id=nil)
    data.each_line do |line|
      line = "data: #{line.strip}\n"
      @body_callback.call(line)
    end
    @body_callback.call "id: #{id}\n" if id
    @body_callback.call "\n"
  end
  
  def each(&block)
    @body_callback = block
  end
  
  def close
    succeed
  end
  
end

class Events < Sinatra::Base
  # register Sinatra::Async

  subscriptions = []

  # The long streaming request
  get '/' do
    sub = Subscription.new
    subscriptions << sub
    env['async.callback'].call [200, {'Content-Type' => 'text/event-stream'}, sub]
    EM::PeriodicTimer.new(1) do
      sub.send("some data")
    end
    throw :async
  end
  
  post '/' do
    subscriptions.each do |s|
      puts "Sending message #{params[:message]}"
      s.send params[:message]
    end
  end
  
  delete '/' do
    subscriptions.each do |s|
      s.send "Slater"
      s.close
    end
  end

end
