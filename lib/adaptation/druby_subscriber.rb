require 'drb'
require 'yaml'

module Adaptation

  module Mom

    class DrubySubscriber

      # constructor, called from the subscribe command
      def initialize subscriber_uri, mom_uri, topics
        @subscriber_uri = subscriber_uri
        @mom_uri = mom_uri
        @topics = topics
        @messages = []
      end

      # method to receive messages, called from the mom
      def send_message message, topic 
        # Insert message into messages buffer, and awake
        # message processor (@sleeper) if paused
        puts "-----------------------------------"
        puts "Received message in topic: #{topic}"
        puts "#{message}"
        puts "-----------------------------------"
        @messages << {:message => message, :topic => topic}
        @sleeper.run if @sleeper.stop?
      end
      
      def subscription_result subscribed
        if subscribed
          puts "Subscribed to mom (#{@mom_uri}). Listening at #{@subscriber_uri}"
        end
      end

      def start
	begin
	  # try to start the subscriber service,
	  # using the uri specified in config/mom.yml
          DRb.start_service(@subscriber_uri, self)
          
	  # subscribe that uri to the mom
	  mom = DRbObject.new(nil, @mom_uri)
          mom.subscribe @subscriber_uri
	rescue Exception => e
          # desired uri already in use
          puts "Couldn't start subscriber at #{@subscriber_uri}. Address already in use?"
          return
	end	
 
        @sleeper = Thread.new{
          loop do 

            # process all messages
            while !@messages.empty?
              @messages.each do |message|         
                if ( (@topics.include?(message[:topic])) or (@topics.include?("all")) )
                  #system("ruby public/dispatch.rb '#{message[:message]}'") 
                  Adaptation::Base.new.process message 
                end
                @messages.delete message
              end
            end

            # go to sleep
            Thread.stop
          
          end
        }

        @sleeper.join
        Drb.thread.join

      end

    end

  end

end
