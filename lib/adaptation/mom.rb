require 'drb'
require 'yaml'

module Adaptation

  module Mom

    class Mom

      def initialize mom_uri
        @mom_uri = mom_uri
        @messages = []
      end

      def subscribe drb_uri
        unless get_subscribers.include?(drb_uri)
          add_subscriber drb_uri
          puts "Added new subscriber: #{drb_uri}"
        end

        oapdaemon = DRbObject.new(nil, drb_uri)
        oapdaemon.subscription_result(true)
      end

      def publish message, topic
       # Insert message into messages buffer, and awake
       # deliverer process (@sleeper) if paused  
        puts "-----------------------------------"
        puts "Received message in topic: #{topic}"
        puts "#{message}"
        puts "-----------------------------------"
        @messages << [message, topic]
        @sleeper.run if @sleeper.stop?
      end

      def start
        DRb.start_service(@mom_uri, self)
        puts "MOM started. Listening at #{@mom_uri}"
     
        @sleeper = Thread.new{
          loop do 

            # deliver all messages
            while !@messages.empty?
              @messages.each do |message|
                get_subscribers.each do |uri|
                  begin
                    puts "Calling #{uri}"
                    DRb.start_service
                    oapdaemon = DRbObject.new(nil, uri)
                    oapdaemon.send_message message[0], message[1]
                  rescue
                    puts "Couldn't send message to subscriber: #{uri}"
                  end
                end
                @messages.delete message
              end
            end

            # go to sleep
            Thread.stop
          
          end
        }
         
        @sleeper.join
        DRb.thread.join # Don't exit just yet
      end

      def list
        puts "MOM subscriptions:"
        get_subscribers.each do |s|
          puts "  #{s}"
        end
        return
      end

    private

      def add_subscriber drb_uri
        subscribers = get_subscribers
        subscribers << drb_uri unless subscribers.include?(drb_uri)
        sf =  File.new('subscribers.yml', 'w')
        sf.write(YAML::dump(subscribers))
        sf.close
      end

      def get_subscribers
        if File.exists?('subscribers.yml')
          subscribers = YAML::load(File.open('subscribers.yml'))
        else
          subscribers = Array.new
        end
        subscribers
      end

    end

  end

end
