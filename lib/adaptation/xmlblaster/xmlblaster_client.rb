require 'xmlrpc/client'
require 'rexml/document'
require 'logger'

# Implements http://www.xmlblaster.org/xmlBlaster/doc/requirements/interface.html

class XmlblasterClient

  attr_reader :xmlblaster_ip

  def initialize( xmlblaster_ip = nil, xmlblaster_port = nil, audit = nil )

    if audit == nil then
      @audit = Logger.new(STDOUT)
      @audit.level = Logger::INFO
    else
      @audit = audit
    end

    @xmlblaster_ip = xmlblaster_ip
    @xmlblaster_port = xmlblaster_port

    @proxy = nil
    @sessionId = nil

    if @xmlblaster_ip then
      begin
        self.connect(@xmlblaster_ip, @xmlblaster_port)
      rescue => e
        @audit.warn( "XMLBlasterClient: Error connecting to XMLBlasterServer." )
        raise e
      end
    end

  end

  def connect( ip, port )
    rpc="/RPC2"
    begin
      @proxy =   XMLRPC::Client.new( ip, rpc, port, nil, nil, nil, nil, nil,nil) 
    rescue => e
      @audit.warn( "XMLBlasterClient: new XMLRPC client creation failed.")
      raise e
    end
    @audit.debug( "XMLBlasterClient: XMLBlaster client to http://#{ip}:#{port}#{rpc}")
    return true
  end

  def login( username='guest', password='guest')
    qos = "<qos>
      <securityService type='htpasswd' version='1.0'>
        <![CDATA[
        <user>#{username}</user>
        <passwd>#{password}</passwd>
        ]]>
      </securityService>
      <session timeout='30000' maxSessions='99' clearSessions='false' />
    </qos>"
    @audit.debug( "XmlbasterClient: authenticate.connect QoS = #{qos}" )
    returnQos = @proxy.call("authenticate.connect", qos)
    @audit.debug( "XmlblasterClient:: authenticate.connect returnQos = #{returnQos}" )
    xml = REXML::Document.new(returnQos)
    @sessionId = xml.elements["//session"].attributes["sessionId"]
  end

  def logout
    begin
      returnValue = @proxy.call("authenticate.logout", @sessionId)
      @audit.debug( "==> ::LOGOUT:: <==      Success with sessionID #{@sessionId}, return Value: #{returnValue.to_s}" )
    rescue  => e
      @audit.warn( "XMLBlasterClient: Error logging out: #{e}" )
      raise e
    end
    return true
  end

  def publish( xmlKey, content, qos )
    begin
      returnValue = @proxy.call("xmlBlaster.publish", @sessionId, xmlKey, content, qos )
      @audit.info( "==> ::PUBLISH:: <==      Success publishing with sessionID #{@sessionId}")
    rescue  => e
      @audit.warn( "XMLBlasterClient: Error publishing to MOM: #{e}" )
      raise e
    end
    return true
  end

  def get( xmlKey, qos )
    begin
      returnValue = @proxy.call("xmlBlaster.get", @sessionId, xmlKey,  qos )
      @audit.info( "==> ::GET:: <==      Success get with sessionID #{@sessionId}" )
    rescue  => e
      @audit.warn( "XMLBlasterClient: Error get from MOM: #{e}" )
      raise e
    end
    return returnValue
  end
  
  def erase( xmlKey, qos )
    begin
      returnValue = @proxy.call("xmlBlaster.erase", @sessionId, xmlKey,  qos )
      @audit.info( "==> ::ERASE:: <==      Success get with sessionID #{@sessionId}" )
    rescue XMLRPC::FaultException => e
      @audit.warn( "XMLBlasterClient: Error erase from MOM: #{e}" )
      raise e
    end
    return true
  end
  
  def printMessage( messages )
    @audit.info( "Received #{messages.length} messages.")
    messages.each{ | message |
      key = message[0]
      content = message[1]
      qos = message[2]
      @audit.info "     Key = " + key.to_s
      @audit.info "     Content = " + content.lenght + " bytes"
      @audit.info "     QOS = " + qos.to_s
    }
  end

end
