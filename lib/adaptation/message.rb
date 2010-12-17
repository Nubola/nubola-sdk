module Adaptation

#= Adaptation::Message -- XML to classes mapping.
#
#Adaptation::Message maps xml data into a ruby object. It also provides validators
#(inspired by ActiveRecord[http://api.rubyonrails.org/classes/ActiveRecord/Validations.html] ORM) 
#to check xml format.
#
#Examples:
#
#      contact = Adaptation::Message.new('<contact><name kind="surname">Name</name></contact>')
#
#      contact.name.content        # -> "Name"
#      contact.names.first.content # -> "Name"
#      contact.names.length        # -> 1
#      contact.name.kind           # -> "surname"
#
#Let's add some validations:
#
#      class Contact < Adaptation::Message
#        validates_presence_of :name
#      end
#
#      contact = Contact.new('<contact><name kind="surname">Name</name></contact>')
#      contact.valid?              # -> true
#
#      contact = Contact.new('<contact><phone>555</phone></contact>')
#      contact.valid?              # -> false
#
#
#      class SeriousContact < Adaptation::Message
#        maps_xml :contact # tell Adaptation that xml data like <contact>...</contact> is mapped by this class
#        validates_value_of :kind, "surname", :in => :names 
#      end
#
#      contact = SeriousContact.new('<contact><name kind="surname">Name</name></contact>')
#      contact.valid?              # -> true
#
#      contact = SeriousContact.new('<contact><name kind="alias">Alias</name></contact>')
#      contact.valid?              # -> false
#  
#More on validations here[link:../rdoc/classes/ActiveRecord/Validations/ClassMethods.html].
#
#
  class Message
   
    attr_reader :id # avoid id method deprecation warnings
 
    @@classes_with_brothers = []
    cattr_reader :classes_with_brothers
    cattr_reader :objects
    
    include Validateable

    # Constructor. Transforms xml passsed as a <em>String</em> to an object wich methods map the input xml elements and attributes.
    def initialize xml_string
      @hash_with_root = XmlSimple.xml_in("<adaptation_wrapper>" + xml_string + "</adaptation_wrapper>", 'ForceArray' => false, 'AttrPrefix' => true) 
 
      first_value = @hash_with_root.values.first
      hash = first_value.is_a?(String) ? {"content" => first_value} : first_value
      array = hash.is_a?(Array) ? hash : [hash]

      array.each do |h|
        if end_of_tree?(h)
          h.each_pair do |k, v|
            if !v.is_a?(Array)
              is_attribute = k.include?("@") ? true : false
              var = k.gsub("@","")
              self.class_eval "attr_accessor :#{var}"         
              eval "@#{var} = v"
              var2 = pluralize(var)
              if !is_attribute and var != var2  
                self.class_eval "attr_accessor :#{var2}"         
                eval "@#{var2} = []; @#{var2} << '#{var}'" 
              end
            else 
              var = pluralize(k.gsub("@",""))
              self.class_eval "attr_accessor :#{var}"         
              eval "@#{var} = []"
              v.each do |val|
                if is_attribute?(val)
                  xml_substring = XmlSimple.xml_out(val, 'NoIndent' => true, 'RootName' => k,   'AttrPrefix' => true)
                  eval "@#{var} << Adaptation::Message.new('#{xml_substring}')"
                else
                  eval "@#{var} << '#{val}'"  
                end
              end 
            end
          end
        else
          h.each_pair do |k,v|
            if k[0..0] == "@"
              var = k.gsub("@","")
              self.class_eval "attr_accessor :#{var}"
              eval "@#{var} = '#{v}'" 
            else
              self.class_eval "attr_accessor :#{k}"
              xml_substring = ""
              if !v.is_a?(Array)
                xml_substring = XmlSimple.xml_out(v, 'NoIndent' => true, 'RootName' => k,   'AttrPrefix' => true)
                eval "@#{k} = Adaptation::Message.new('#{xml_substring}')"
                k2 = pluralize(k)
                if k != k2  
                  self.class_eval "attr_accessor :#{k2}"
                  eval "@#{k2} = []; @#{k2} << @#{k}" 
                end
              else
                k2 = pluralize(k)
                self.class_eval "attr_accessor :#{k2}"
                eval "@#{k2} = [];" 
                v.each do |val|  
                  xml_substring = XmlSimple.xml_out(val, 'NoIndent' => true, 'RootName' => k, 'AttrPrefix' => true) 
                  eval "@#{k} = Adaptation::Message.new('#{xml_substring}')"
                  eval "@#{k2} << @#{k}" 
                end
              end
            end
          end
        end
      end

    end

    def self.has_one *symbols #:nodoc:
      logger.info "has_one is deprecated and not necessary"
    end

    def self.has_text #:nodoc:
      logger.info "has_text is deprecated and not necessary"
    end
   
    def self.has_many *options #:nodoc: 
      logger.info "has_many is deprecated and not necessary"
    end

    # Defines the xml element that this class is mapping. This is useful to avoid class
    # name collisions:
    #
    # Example:
    #
    #   We already have a database table called 'things' and we
    #   interoperate with it with an ActiveRecord subclass called
    #   'Thing':
    #
    #     class Thing < ActiveRecord::Base
    #       ...
    #     end
    #
    #   But in the same Adaptation application we want to parse the
    #   following xml:
    #     
    #     <thing>...</thing>
    #
    #   Defining another class Thing would produce a class name 
    #   collision, but we can do:
    #
    #     class XmlThing < Adaptation::Message
    #       maps_xml :thing
    #       ...     
    #     end
    #
    #   and store it in a file called app/messages/thing.rb
    #
    def self.maps_xml element
      @mapped_xml = element
    end

    # Returns the xml element this class is mapping
    def self.mapped_xml
      @mapped_xml || self.to_s.downcase.gsub("::","_").to_sym
    end

    def self.get_class_object(mapped_xml) #:nodoc:
      # TODO: reimplement this as read in ruby-talk (using 'inherited' method)
      mapped_xml = mapped_xml.downcase.to_sym if mapped_xml.is_a?(String)
      klass = nil
      ObjectSpace.each_object(Class) do |c|
        next unless c.ancestors.include?(Adaptation::Message) and (c != self) and (c != Adaptation::Message)
        (klass = c and break) if c.mapped_xml == mapped_xml rescue next
      end
      klass
    end

    # <em>Deprecated</em>, use <em>new</em> instead.
    def self.to_object xml_message #:nodoc:
       logger.info "to_object is deprecated, use new instead"
       self.new(xml_message)
    end

    # <em>Deprecated</em>, use <em>valid?</em> instead.
    def check #:nodoc:
      logger.info "check is deprecated, use valid? instead"
      valid?
    end

    def self.logger#:nodoc:#
      Adaptation::Base.logger rescue Logger.new(STDOUT)
    end

    def to_xml
      xml_out(@hash_with_root).gsub("\"","'").gsub(/(<|<\/)content(>| *\/>)/,"")
    end

    def to_hash
      @hash_with_root
    end

    private
    
    def end_of_tree?(v) #:nodoc:
      return true if v.has_key? "content"
      return true if v.values.length == 1 and v.values.first.is_a?(Array) and v.values.first.reject{|val| val.is_a?(String) or is_attribute?(val)}.length == 0
      false
    end

    def xml_in(xml_string)
      XmlSimple.xml_in(xml_string, 'ForceArray' => false, 'AttrPrefix' => true, 'KeepRoot' => true)
    end

    def xml_out(xml_hash)
      XmlSimple.xml_out(xml_hash, 'NoIndent' => true, 'RootName' => k, 'AttrPrefix' => true)
    end

    # TODO: improve this
    def pluralize(v) #:nodoc:
      v[(v.length - 1)..v.length] == "s" ? v : v + "s"
    end

    def is_attribute?(h) #:nodoc:
      return false unless h.is_a?(Hash)
      return true if h.length == 1 and h.values.first.is_a?(String)
      false
    end

  end
  
end
