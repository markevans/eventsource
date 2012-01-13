require 'sinatra'
require 'eventmachine'

class Connection
  include EM::Deferrable
  
  # CLASS METHODS
  class << self
    def find(id)
      instances[id]
    end
    
    def send_all(message)
      instances.each{|id, conn| conn.send message }
    end
    
    def destroy_all
      instances.each{|id, conn| conn.destroy }
    end
    
    def count
      instances.count
    end

    def instances
      @instances ||= {}
    end
  end

  # INSTANCE METHODS
  
  def initialize(id)
    @id = id
    @keep_alive_timer = EM.add_periodic_timer(29){ send("") }
    self.class.instances[id] = self
  end
  
  attr_reader :id
  
  def send(data)
    data.each_line{|line| output data_line(line) }
    output id_line(id)
    output end_message_line
    self.last_sent_to = Time.now
  end
  
  def each(&block)
    @body_callback = block
  end
  
  def close
    keep_alive_timer.cancel
    succeed
  end
  
  def destroy
    send "Slater"
    close
    self.class.instances.delete id
  end
  
  private
  
  attr_accessor :last_sent_to
  attr_reader :keep_alive_timer
  
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

  def log(message)
    Rails.logger.debug(message)
    Rails.logger.debug("Number of connections: #{Connection.count}")
  end

  # The long streaming request
  get '/' do
    id = params[:id]
    log "CALLING GET / with ID #{id}"
    if Connection.find(id)
      "Already established a connection"
    else
      conn = Connection.new(id)
      env['async.callback'].call [200, {'Content-Type' => 'text/event-stream'}, conn]
      throw :async
    end
  end
  
  post '/' do
    log "CALLING POST /"
    Connection.send_all params[:message]
    "OK"
  end
  
  delete '/' do
    log "CALLING DELETE /"
    Connection.destroy_all
    "OK"
  end
  
  post '/conn/:id' do |id|
    log "CALLING POST /CONN/:ID"
    connection = Connection.find(id)
    connection.send params[:message]
    "OK"
  end
  
  delete '/conn/:id' do |id|
    log "CALLING DELETE /CONN/:ID"
    connection = Connection.find(id)
    connection.destroy if connection
    "OK"
  end

end
