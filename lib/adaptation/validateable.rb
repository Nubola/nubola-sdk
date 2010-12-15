module Validateable

  [:save, :save!, :update_attribute].each{|attr| define_method(attr){}}

  def method_missing(symbol, *params)
    if(symbol.to_s =~ /(.*)_before_type_cast$/)
      send($1)
    end
  end

  def self.append_features(base)
    super
    base.send(:include, ActiveRecord::Validations)
  end


  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  module ClassMethods
    # Define class methods here.
   
    def self_and_descendents_from_active_record # :nodoc:
      klass = self
      classes = [klass]
      while klass != klass.base_class
        classes << klass = klass.superclass
      end
      classes
    rescue
      [self]
    end
 
    def human_name
      ""
    end

    def human_attribute_name(attribute_key_name, options = {})
      ""
    end

  end


end

#= Adaptation::Message Validations
# {ActiveRecord validations}[http://api.rubyonrails.org/classes/ActiveRecord/Validations/ClassMethods.html] should work
# the same way, except those that have been overwritten here.
#
module ActiveRecord
  module Validations
    module ClassMethods

      # Validates whether the specified xml attribute/element is present (not nil or blank).
      #
      # Example 1:
      # 
      #   class Leftwing < Adaptation::Message
      #     validates_presence_of :side
      #   end
      #
      #   lw = Leftwing.new("<leftwing side=\"left\"/>")
      #   lw.valid?  # -> true
      #   lw = Leftwing.new("<leftwing noside=\"left\"/>")
      #   lw.valid?  # -> false
      # 
      # Example 2:
      #
      #   class Bird < Adaptation::Message
      #     validates_presence_of :side, :in => "birds.wings"
      #   end
      #
      #   b = Bired.new('<birds><bird><wings><wing side="left"/><wing side="right"/></wings></bird></birds>')
      #   b.valid?   # -> true
      #   b = Bired.new('<birds><bird><wings><wing side="left"/><wing noside="right"/></wings></bird></birds>')
      #   b.valid?   # -> false
      #
      def validates_presence_of(*attr_names)
        configuration = {
          :message => 'cannot be blank' 
        }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        if configuration[:in].nil?
          validates_each(attr_names, configuration) do |record, attr_name, value|
            string = record.send(attr_names[0].to_sym) 
            unless string.nil?
              string = string.content if string.is_a?(Adaptation::Message)
            end
            if string.blank?
              record.errors.add(attr_name, configuration[:message])
            end
          end
        else
          validates_each(attr_names, configuration) do |record, attr_name, value|
            missing = false
            configuration_in = configuration[:in].to_s
            elements = configuration_in.to_s.split('.')
            subelement = record
            while elements.length > 1
              subelement = record.send(elements[0].to_sym)
              elements.slice!(0)
            end

            if !subelement.is_a?(Array)             
              subelement.send(elements[0].to_sym).each do |s|
                string = s.send(attr_names[0].to_sym) 
                unless string.nil?
                  string = string.content unless string.is_a?(String)
                end
                if string.blank?
                  missing = true
                  break
                end
              end
            else
              subelement.each do |sub|
                sub.send(elements[0].to_sym).each do |s|
                  string = s.send(attr_names[0].to_sym) 
                  unless string.nil?
                    string = string.content unless string.is_a?(String)
                  end
                  if string.blank?
                    missing = true
                    break
                  end
                end
                break if missing
              end
            end

            record.errors.add(attr_name, configuration[:message]) if missing
          end
        end
      end

      # Validates whether the value of the specified xml attribute/element is the expected one.
      #
      # Example 1:
      # 
      #   <leftwing side="left"/>
      #
      #   class Leftwing < Adaptation::Message
      #     validates_value_of :side, "left"
      #   end
      # 
      # Example 2:
      #   <bird><wings><wing side="left"/><wing side="right"/></wings></bird>
      #
      #   class Bird < Adaptation::Message
      #     validates_value_of :side, "left", :in => :wings
      #   end
      #
      def validates_value_of(*attr_names)
        configuration = {
          :message => 'value doesn\'t exist' 
        }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        if configuration[:in].nil?
          validates_each(attr_names, configuration) do |record, attr_name, value|
            string = record.send(attr_names[0].to_sym) 
            unless string.nil?
              string = string.content unless string.is_a?(String)
            end
            if (attr_names[1].to_s != string)
              record.errors.add(attr_name, configuration[:message])
            end
          end
        else
          validates_each(attr_names, configuration) do |record, attr_name, value|
            found = false
            configuration_in = configuration[:in].to_s
            elements = configuration_in.to_s.split('.')
            subelement = record
            while elements.length > 1
              subelement = record.send(elements[0].to_sym)
              elements.slice!(0)
            end
            subelement.send(elements[0].to_sym).each do |s|
              string = s.send(attr_names[0].to_sym) 
              unless string.nil?
                string = string.content unless string.is_a?(String)
              end
              if (attr_names[1].to_s == string)
                found = true
                break
              end
            end
            record.errors.add(attr_name, configuration[:message]) unless found
          end
        end
      end
      
      # Validates whether the value of the specified xml attribute/element has a valid email format.
      #
      # Example:
      #
      #   class Contact < Adaptation::Message
      #     validates_as_email :email
      #   end 
      #
      #   c = Contact.new('<contact email="mail@xample.com">...</contact>')
      #   c.valid?  # -> true
      #   c.email = "nomail"
      #   c.valid?  # -> false
      #
      def validates_as_email(*attr_names)
        configuration = {
          :message   => 'is an invalid email',
          :with      => RFC822::EmailAddress,
          :allow_nil => true }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        validates_format_of attr_names, configuration
      end

    end
  end
end

