require "adaptation/xmlblaster/xmlblaster_client.rb"
require "adaptation/xmlblaster/xmlblaster_callback_server.rb"

class XmlblasterCallbackClient < XmlblasterClient

  attr_reader :callback_server

  def initialize( xmlblaster_ip = nil, xmlblaster_port = "8080", callback_ip = "127.0.0.1", callback_port = "8081", callback_public_ip = nil, callback_public_port = nil, audit = nil)
    super xmlblaster_ip, xmlblaster_port, audit
    @xmlblaster_ip = xmlblaster_ip
    @xmlblaster_port = xmlblaster_port
    @callback_ip = callback_ip
    @callback_port = callback_port
    @callback_public_ip = callback_public_ip || @callback_ip
    @callback_public_port = callback_public_port || @callback_port
    @callback_server = nil
    @audit = audit

    begin
      @callback_server = XmlblasterCallbackServer.new( @callback_ip, @callback_port, @callback_public_ip, @callback_public_port, self, @audit )
    rescue => e
      @audit.warn( "XMLBlasterCallbackClient: Could not create CallbackServer" )
      raise e
    end

    begin
      @callback_server.start()
    rescue => e
      @audit.warn( "XMLBlasterCallbackClient: Error creating XMLRPC Server" )
      raise e
    end

    if @callback_public_ip
      @audit.info "MOM xmlBlaster #{@xmlblaster_ip}:#{@xmlblaster_port} <---> Public IP #{@callback_public_ip}:#{@callback_public_port} <-- NAT --> This host #{@callback_ip}:#{@callback_port}"
    else
      @audit.info "MOM xmlBlaster #{@xmlblaster_ip}:#{@xmlblaster_port} <---> This subscriber #{@callback_public_ip || @callback_ip}:#{@callback_public_port || @callback_port}"
    end 

  end

  def login( username='guest', password='guest' )
    qos = "<qos>
      <securityService type='htpasswd' version='1.0'>
        <![CDATA[
        <user>#{username}</user>
        <passwd>#{password}</passwd>
        ]]>
      </securityService>
      <session name ='#{username}/1' timeout='0' maxSessions='1' clearSessions='true' />
      <persistent/>
      <callback type='XMLRPC' retries='-1' delay='60000'>#{@callback_server.callback_url}</callback>
    </qos>"
    @audit.debug( "XmlblasterCallbackClient: authenticate.connect QoS = #{qos}" )
    returnQos = @proxy.call("authenticate.connect", qos)
    @audit.debug( "XmlblasterCallbackClient: authenticate.connect returnQos = #{returnQos}" )
    xml = REXML::Document.new(returnQos)
    @sessionId = xml.elements["//session"].attributes["sessionId"]
  end

  def subscribe( xmlKey, qos )
    begin
      returnValue = @proxy.call("xmlBlaster.subscribe", @sessionId, xmlKey, qos )
      @audit.debug( "==> ::SUBSCRIBE:: <==      Success subscribing with sessionID #{@sessionId}" )
    rescue  => e
      @audit.warn( "XMLBlasterClient: Error subscribing to MOM: #{e}" )
      raise e
    end
    return returnValue
  end

  def unsubscribe( xmlKey, qos )
    begin
      returnValue = @proxy.call("xmlBlaster.unSubscribe", @sessionId, xmlKey,  qos )
      @audit.debug( "==> ::UNSUBSCRIBE:: <==      Success unSubscribing with sessionID #{@sessionId}" )
    rescue  => e
      @audit.warn( "XMLBlasterClient: Error unsubscribing from MOM: #{e}" )
      raise e
    end
    return true
  end

  def update( *args )
    key =args[0]
    content = args[1]
    qos = args[2]
    @audit.debug( "XMLBlasterCallbackClient: Received UPDATE." )

    begin
      qos_xml = REXML::Document.new args[2]
    rescue => e
      @audit.warn( "XMLBlasterCallbackClient: Could not open QOS of message." )
    end

    if qos_xml.elements['qos'].elements['state'] != nil then
      begin
        value = qos_xml.elements['qos'].elements['state'].attributes['id'].to_s
        if value == "ERASED" then
          @audit.debug( "XMLBlasterCallbackClient: TOPIC GOT ERASED" )
        else
          @audit.debug( "XMLBlasterCallbackClient: SOMETHING STRANGE" )
        end
      rescue  => e
        @audit.warn( "XMLBlasterCallbackClient: Error: #{e}" )
      end
    end

    begin
      key_xml = REXML::Document.new key
      topic = key_xml.elements['key'].attributes["oid"]
      @audit.debug "-----------------------------------"
      @audit.debug "Received message in topic: #{topic}"
      @audit.debug "#{content}"
      @audit.debug  "-----------------------------------"
      # process message
      Adaptation::Base.new.process content
    rescue => e
      @audit.warn( "#{e}. XMLBlasterCallbackClient: Could not access content of message." )
    end   

    return "<qos><state>OK</state></qos>"
  end

  def ping( *args )
    @audit.debug( "XMLBlasterClient: received PING - PONG" )
    return "<qos><state>OK</state></qos>"
  end

  def logout
    super
    if @callback_server then
      begin
        @callback_server.shutdown()
      rescue => e
        @audit.warn( "XMLBlasterCallbackClient: Error could not stop CallbackServer" )
        raise e
      end
    else
      return false
    end   
    return true
  end

end



