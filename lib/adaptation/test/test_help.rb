#set environment
ADAPTOR_ENV = "test"

require 'adaptation'

Adaptation::Initializer.run

begin
  require 'active_record/test_case'
  require 'active_record/fixtures'
rescue Exception => e
  puts "Problem with database fixtures: #{e}"
  raise e
end

require 'erb'

class ActiveSupport::TestCase

  include ActiveRecord::TestFixtures
  self.fixture_path = "#{ADAPTOR_ROOT}/test/fixtures/"
  self.use_instantiated_fixtures  = false
  self.use_transactional_fixtures = false

  # Asserts that a message[link:/classes/Adaptation/Message.html] in a xml
  # fixture file is converted into an Adaptation::Message that if serialized
  # again to xml is equivalent to the xml data in the initial fixture file.
  def assert_parsed message_symbol
    data, message_object = load_message_fixture message_symbol
   
    #parsed_data = Adaptation::Message.new(data)
    error = build_message error, 
            "? not parsed ok:\n initial: ?\n parsed:  ?", 
            message_symbol.to_s, 
            data, 
            message_object.to_xml
    assert_block error do
      compare_xml_elements data, message_object.to_xml
    end
  end

  # Asserts that an Adaptation::Message message[link:/classes/Adaptation/Message.html]
  # build from a xml fixture file passes all the validations specified in the
  # class definition.
  def assert_validates message_symbol
    data, message_object = load_message_fixture message_symbol
    error = build_message error,
            "invalid message ?",
            message_symbol.to_s
    message_object.clear_errors
    assert_block error do
      message_object.valid?
    end
  end

  # Asserts that an Adaptation::Message message[link:/classes/Adaptation/Message.html],
  # build from a xml fixture file doesn't pass all the validations specified in
  # the class definition.
  def assert_not_validates message_symbol
    data, message_object = load_message_fixture message_symbol
    error = build_message error,
            "? message shouldn't validate",
            message_symbol.to_s           
    assert_block error do
      !message_object.valid?
    end
  end

  # Asserts that a message[link:/classes/Adaptation/Message.html] has been
  # published in test environment. This means that the
  # message[link:/classes/Adaptation/Message.html] will be searched in the
  # file where the mock object <em>test/mocks/test/publish.rb</em> left it.
  # The file that fakes the mom is deleted every time <em>message<em> method
  # is called.
  def assert_message_published xml_message
    message_object = xml_message

    if message_object.is_a?(String)
      # build Message object with xml_data
      message_type = xml_message[1..(xml_message.index(/(>| )/) - 1)]
      message_class = Adaptation::Message.get_class_object(message_type.capitalize)
      message_object = message_class.nil? ? Adaptation::Message.new(xml_message) : message_class.new(xml_message)
    end

    # check for all messages "published" in the mom (that's file /tmp/mom.txt),
    # if any line corresponds to the message passed as a parameter.
    message_found = false
    expected = published = ""
    File.open(ADAPTOR_ROOT + '/test/mocks/test/mom.txt', 'r').each{ |line|
      published   =  line.chop
      expected    =  message_object.to_xml.to_s
      if compare_xml_elements published, message_object.to_xml
        message_found = true
        break 
      end
    }
 
    error = build_message(error,
      "? message not published:\n \
  Expected : ?\n \
  Published: ?\n",
      message_object.class,
      expected,
      published)
    assert_block error do
      message_found
    end
    
  end

  # Asserts a database exists. To do so this method tries to establish a
  # connection with the specified database. Conection information must
  # be provided with a hash:
  # <tt>:database</tt>:: <tt>=> database name</tt>
  # <tt>:host</tt>::     <tt>=> database host</tt>
  # <tt>:username</tt>:: <tt>=> database user</tt>
  # <tt>:password</tt>:: <tt>=> database password</tt>
  # <tt>:adapter</tt>::  <tt>=> database type (default is "mysql")</tt>
  # These options correspond to those in
  # Activerecord::Base.establish_conection[http://ar.rubyonrails.com/classes/ActiveRecord/Base.html#M000370]
  def assert_database_present db_settings_hash
    update_activerecord_test_configuration db_settings_hash

    ActiveRecord::Base.remove_connection
    
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[ADAPTOR_ENV])

    database_exists = true
    begin
      connection = ActiveRecord::Base.connection
    rescue Exception => e
      database_exists = false
    end

    error = build_message error,
            "? database not found",
            ActiveRecord::Base.configurations[ADAPTOR_ENV][:database]
    assert_block error do
      database_exists
    end

  end

  # Asserts a database doesn't exist. To do so this method tries to establish a
  # connection with the specified database. Connection information must
  # be provided with a hash. This method assert if connection fails, but that
  # could also mean that provided connection hash is wrong. The connection options
  # are the same as in assert_database_present:
  # <tt>:database</tt>:: <tt>=> database name</tt>
  # <tt>:host</tt>::     <tt>=> database host</tt>
  # <tt>:username</tt>:: <tt>=> database user</tt>
  # <tt>:password</tt>:: <tt>=> database password</tt>
  # <tt>:adapter</tt>::  <tt>=> database type (default is "mysql")</tt>
  # These options correspond to those in
  # Activerecord::Base.establish_conection[http://ar.rubyonrails.com/classes/ActiveRecord/Base.html#M000370]
  def assert_database_not_present db_settings_hash
    update_activerecord_test_configuration db_settings_hash

    ActiveRecord::Base.remove_connection

    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[ADAPTOR_ENV])

    database_exists = true
    begin
      connection = ActiveRecord::Base.connection
    rescue Exception => e
      database_exists = false
    end

    error = build_message error,
            "? database shouldn't exist",
            ActiveRecord::Base.configurations[ADAPTOR_ENV][:database]
    assert_block error do
      !database_exists
    end

  end

  # Asserts a file exists
  def assert_file_present file
    error = build_message error,
            "? not found",
            file
    assert_block error do
      File.exists?(file)
    end
  end

  # Asserts a file doesn't exist
  def assert_file_not_present file
    error = build_message error,
            "? shouldn't exist",
            file
    assert_block error do
      !File.exists?(file)
    end
  end
  
  # Builds a message[link:/classes/Adaptation/Message.html] from a xml fixture
  # file and processes it the same way messages from the mom are processed by
  # adaptation, but using a test environment. Messages published with 
  # {publish}[link:/classes/Adaptation/Adaptor.html#M000170] will be published 
  # to a mocked MOM (and can be checked with _assert_message_published_)
  def message message_symbol
    # build a message object from fixture
    message_xml, message_object = load_message_fixture message_symbol

    # load mock objects
    Dir["test/mocks/test/*.rb"].each do |f|
      require f
    end 

    # clean mom (delete mom.txt file)
    mom_mock_file = ADAPTOR_ROOT + '/test/mocks/test/mom.txt'
    if File.exists? mom_mock_file
      File.delete mom_mock_file
    end

    Adaptation::Base.process message_xml

  end

  # Returns an Adaptation::Message object from a fixture, without processing it 
  # (or an instance of the corresponding subclass, if it's defined).
  def get_message_from_fixture message_symbol
    load_message_fixture(message_symbol)[1]
  end
  
  private

  def get_message_fixture fixture_name #:nodoc:
    fixture_file = ADAPTOR_ROOT + '/test/fixtures/' + fixture_name + '.xml'
    fixture_contents = ""
    File.open(fixture_file).each { |line|
      unless line =~ /^ {0,}#/
        fixture_contents << line.strip.chomp
      end
    }
    ERB.new(fixture_contents.chomp).result
  end

  def load_message_fixture fixture_symbol #:nodoc:
    data = get_message_fixture(fixture_symbol.to_s)
    class_name =  data[1..(data.index(/(>| )/) - 1)].capitalize
    message_class = Adaptation::Message.get_class_object(class_name) 
    message_object = message_class.nil? ? Adaptation::Message.new(data) : message_class.new(data)
    [data, message_object]
  end
  
  def compare_xml_elements element1, element2 #:nodoc:
    element1 = REXML::Document.new(element1) if element1.is_a?(String)
    element2 = REXML::Document.new(element2) if element2.is_a?(String)
    if element1.has_attributes?
       if !element2.has_attributes?
         return false
       end
       element1.attributes.to_a.each do |a|
         if !element2.attributes.to_a.include?(a)
           return false
         end
       end
    end
    if element1.has_text?
      if !element2.has_text?
        return false
      end
      if element1.text != element2.text
        return false
      end
    end
    if element1.has_elements?
      if !element2.has_elements?
        return false
      end
      element1.elements.to_a.each do |e1|
        element_exists = false
        element2.elements.to_a.each do |e2|
          result = compare_xml_elements e1, e2
          if result == true
            element_exists = true
            break
          end
        end
        if element_exists == false
          return false
        end
      end
    end

    return true
  end
  
  def update_activerecord_test_configuration db_settings_hash #:nodoc:
    unless db_settings_hash.nil?
      ActiveRecord::Base.configurations.update("test" => db_settings_hash)
    end
  end
  
end
