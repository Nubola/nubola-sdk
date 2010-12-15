require 'xmlrpc/server'
require 'socket'
require 'logger'

class XmlblasterCallbackServer

  attr_reader :thread
  attr_reader :callback_url

  def initialize( ip, port, public_ip, public_port, callbackInstance, audit = nil )
    if audit == nil then
      @audit = Logger.new($stdout)
    else
      @audit = audit
    end
    @thread = nil
    @callback_server = nil
    @callback_url = "http://#{public_ip}:#{public_port}/RPC2"
    @port = port
    @ip = ip
    @callback_instance = callbackInstance
  end

  def start
    
    begin
      @callback_server = XMLRPC::Server.new( @port, @ip, 4, @audit, false )
      @audit.debug( "CallBackServer started")
    rescue => e
      msg = e.message + ": " + e.backtrace.join("\n")
      @audit.error( "CallBackServer: Could not create XMLRPC Server: " + msg)
      return false
    end

    @thread = Thread.new( @port, @callback_instance ) { | port, callback_instance | 
      Thread.current['name'] = "MOM-CallbackServer"
      STDOUT.sync = true


      if @callback_server then      

        @audit.debug( "MOM-CallBackServer: " + @callback_url )
        
        @callback_server.add_handler("ping") do |name, *args|
          @callback_instance.ping( *args )
        end

        @callback_server.add_handler("update") do |name, *args|
          @callback_instance.update( *args )
        end

        @callback_server.set_default_handler do |name, *args|
          raise XMLRPC::FaultException.new(-99, "MOM-CallBackServer: Method #{name} missing or wrong number of parameters!")
        end

        # listening
        @audit.debug( "MOM-CallBackServer: XMLRPC Server serving." )
        @callback_server.serve()

      else
        return false
      end
      
    }
    
    return true
  end


  def shutdown
    if @callback_server then
      @callback_server.shutdown()
      @thread.kill
    end
    return true
  end

end

