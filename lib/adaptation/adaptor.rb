module Adaptation
#= Adaptation::Adaptor -- The message processor
#
#Adaptation::Adaptor is the base class for those classes containing the logic to be executed when a message is read through the mom. 
#
#Each class extending Adaptation::Adaptor must implement the _process_ function, using it as the main entry point for the logic to be executed when a message arrives. The name of the class extending Adaptation::Message associates the class with the one to be executed when a message arrives. Ie. if a message is received with a root element named <hello>, adaptation will search for a class extending Adaptation::Adaptor named _HelloAdaptor_. 
#
#<i>Adaptation::Adaptors</i> (classes extending Adaptation::Adaptor) must be stored under <i>app/adaptors_name</i> in the adaptation file tree. This is done automatically when an adaptor is generated using adaptation built-in generator:
#  script/generate adaptor hello
# 
  class Adaptor

    attr_reader :message

    def process message #:nodoc:
      @message = message
    end

    # Returns the logger to output results in the current environment log file.
    # Example:
    #   > logger.info "this is going to log/development.log"
    def logger
      Adaptation::Base.logger
    end

    # Publishes a message to the MOM. The message can be an instance of Adaptation::Message or a String.
    #
    # When executed in test environment messages are not published to the MOM. They are written to a mocked MOM
    # and their publication can be asserted in tests with assert_message_published[link:/classes/ActiveSupport/TestCase.html#M000038].
    #
    # By default it uses <b>script/publish</b> ito publish. This can be overwritten specifying the
    # <b>oappublish</b> instruction in configuration file <b>config/settings.yml</b>.
    #
    # By default it publishes in topic <b>ADAPTATION</b>. This can be overwritten specifying the <b>application</b> setting
    # in <b>config/settings.yml</b> file.
    #
    # Example settings file:
    #    oappublish: /bin/echo
    #    application: MY_TOPIC
    def publish *options                                                                         
      message_object = nil                                                                       
      if options.first.is_a?(Message)                                                            
        message_object = options.first                                                           
      elsif options.first.is_a?(String)
        xml_message = options.first
        message_type = xml_message[1..(xml_message.index(/(>| )/) - 1)]
        message_class = Adaptation::Message.get_class_object(message_type.capitalize)
        message_object = message_class.new(xml_message)
      end
      
      xml = message_object.to_xml.to_s.gsub("'", "\"")
      publish_method = $config["oappublish"] || "#{ADAPTOR_ROOT}/script/publish"
      topic = $config["application"] || "ADAPTATION"
      unless system("#{publish_method} '#{$config["application"]}' '#{xml}'")
        logger.error "Problem publishing: #{xml}"
      end

    end

    def self.get_class_object(adaptor_class) #:nodoc:
      Object.const_get(adaptor_class) rescue nil
    end

    # Extract the gid attribute from the message
    #   Example:
    #     message = <install gid="90".../>
    #     returns "90" (String)
    def gid
      @message.gid
    end

    # Returns the message type as a donwcase String
    #   Example:
    #     message: <addhostresponse .../>
    #     returns "addhostresponse"
    def message_type
      @message.message_type if @message
    end

  end

end
