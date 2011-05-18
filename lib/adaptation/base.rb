module Adaptation

  ADAPTOR_ENV = 'development' unless defined? ADAPTOR_ENV

  class Initializer

    def self.run
       
      if File.exists?("#{ADAPTOR_ROOT}/config/settings.yml")
        $config = YAML::load(File.open("#{ADAPTOR_ROOT}/config/settings.yml"))[ADAPTOR_ENV]
      end

      # connect with database -> this could also be avoided?
      if File.exists?("#{ADAPTOR_ROOT}/config/database.yml")
        environment_configurations = YAML::load(File.open("#{ADAPTOR_ROOT}/config/database.yml"))[ADAPTOR_ENV]
        ActiveRecord::Base.configurations.update(ADAPTOR_ENV => environment_configurations)
        ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[ADAPTOR_ENV])
      end

      # require all adaptors
      require "#{ADAPTOR_ROOT}/app/adaptors/application.rb" if File.exist?("#{ADAPTOR_ROOT}/app/adaptors/application.rb")
      Dir["#{ADAPTOR_ROOT}/app/adaptors/*.rb"].each do |f|
        require f
      end

      # require all messages
      Dir["#{ADAPTOR_ROOT}/app/messages/*.rb"].reject{|f| f =~ /\/_/}.each do |f|
        require f
      end

      # require all models
      Dir["#{ADAPTOR_ROOT}/app/models/*.rb"].each do |f|
        require f
      end

    end

  end


  class Base

    cattr_accessor :logger

    def self.process(xml_message)

      Adaptation::Base.logger = Logger.new(STDOUT) if logger.nil?
      ActiveRecord::Base.logger = logger

      logger.debug "Adaptation::Base.process #{xml_message}"

      # if xml_message is '<login gid="1234_test" id="ASDF" />'
      # then message_type is 'login'
      if xml_message =~ /<(\S+)/
        message_type = $1.capitalize
      end
      adaptor = message = nil
 
      message_class = Adaptation::Message.get_class_object(message_type) rescue nil
      logger.debug "message_class = #{message_class ? message_class : 'Adaptation::Message'}" 

      message = message_class.nil? ? Adaptation::Message.new(xml_message) : message_class.new(xml_message)

      adaptor_class = Adaptation::Adaptor.get_class_object("#{message_type}Adaptor") rescue nil    
      logger.debug "adaptor_class = #{adaptor_class ? adaptor_class : 'AdaptationAdaptor'}" 

      adaptor = adaptor_class.nil? ? ApplicationAdaptor.new : adaptor_class.new rescue AdaptationAdaptor.new

      unless message.valid?
        logger.info "WARNING:Message doesn't validate!" 
        return
      end

      adaptor.process message
    end

  end

end
