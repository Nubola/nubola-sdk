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

      ActiveRecord::Base.logger = logger

      logger.debug "Adaptation::Base.process #{xml_message}"

      # dirty method to discover the message type
      # TODO: move to a module
      message_type = xml_message[1..(xml_message.index(/(>| |\/)/) - 1)] rescue nil
      adaptor = message = nil
 
      message_class = Adaptation::Message.get_class_object(message_type.capitalize) rescue nil
      message = message_class.nil? ? Adaptation::Message.new(xml_message) : message_class.new(xml_message)
        
      adaptor_class = Adaptation::Adaptor.get_class_object("#{message_type.capitalize}Adaptor") rescue nil    
      adaptor = adaptor_class.nil? ? ApplicationAdaptor.new : adaptor_class.new rescue Adaptation::Adaptor.new

      unless message.valid?
        logger.info "WARNING:Message doesn't validate!" 
        return
      end

      adaptor.process message
    end

  end

end
