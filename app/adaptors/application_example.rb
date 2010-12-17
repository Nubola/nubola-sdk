# TODO - NOTE
# This is an example implementation

class ApplicationExampleAdaptor < Adaptation::Adaptor
  # When a message without matching adaptor is received, 
  # Adaptation tries to process it with ApplicationAdaptor
  # (the basic Adaptor from which the rest inherit).
  # Since Adaptation doesn't recognise the message, it is passed
  # as a String, because Adaptation doesn't know how to
  # build Adaptation::Message objects for undefined messages yet.
  def process message
    @message = message

    type = message_type

    if message.include?(hostname) && ["install", "installresponse", "backup", "restore", "uninstall"].include?(type)
      if message.include?("<app id=\"FUNAMBOL80\"")
        run_adaptor(funambol80_installer_adaptor)
      end
      if message.include?("<app id=\"SUGARCRM52\"")
        run_adaptor(sugarcrm52_installer_adaptor)
        run_adaptor(funambol80_installer_adaptor)
      end
      if message.include?("<app id=\"ORANGEHRM\"")
        run_adaptor(orangehrm_installer_adaptor)
      end
      if message.include?("<app id=\"KNOWLEDGETREE\"")
        run_adaptor(knowledgetree_installer_adaptor)
      end
      if message.include?("<app id=\"MOODLE19\"")
        run_adaptor(moodle19_installer_adaptor)
      end
        
    elsif ["adduser", "deluser"].include?(type)
      if message.include?("<app id=\"FUNAMBOL80\"")
        run_adaptor(funambol80_instance_adaptor)
      end
      if message.include?("<app id=\"SUGARCRM52\"")
        run_adaptor(sugarcrm52_instance_adaptor)
      end
      if message.include?("<app id=\"ORANGEHRM\"")
        run_adaptor(orangehrm_instance_adaptor)
      end      
      if message.include?("<app id=\"KNOWLEDGETREE\"")
        run_adaptor(knowledgetree_instance_adaptor)
      end
      if message.include?("<app id=\"MOODLE19\"")
        run_adaptor(moodle19_instance_adaptor)
      end

    elsif ["login", "logout"].include?(type)
      run_adaptor(sso_adaptor)
      run_adaptor(funambol80_instance_adaptor)
      run_adaptor(sugarcrm52_instance_adaptor)
      run_adaptor(orangehrm_instance_adaptor)
      run_adaptor(knowledgetree_instance_adaptor)
      run_adaptor(moodle19_instance_adaptor)

    else
      logger.info "Message not for a VM: #{message}"

    end

  end

  private

  # Returns the path to the SSO adaptor dispatch.rb
  def sso_adaptor
    "sso/adapted_application/adaptor/public/dispatch.rb"
  end

  # Returns the path to the FUNAMBOL80 installer dispatch.rb
  def funambol80_installer_adaptor
    "funambol8.0/installer/public/dispatch.rb"
  end

  # Returns the path to the SUGARCRM52 installer dispatch.rb
  def sugarcrm52_installer_adaptor
    "sugarcrm5.2/installer/public/dispatch.rb"
  end

  # Returns the path to the ORANGEHRM installer dispatch.rb
  def orangehrm_installer_adaptor
    "orangehrm2.2/installer/public/dispatch.rb"
  end

  # Returns the path to the KNOWLEDGETREE installer dispatch.rb
  def knowledgetree_installer_adaptor
    "knowledgetree3.5/installer/public/dispatch.rb"
  end

  # Returns the path to the MOODLE19 installer dispatch.rb
  def moodle19_installer_adaptor
    "moodle1.9/installer/public/dispatch.rb"
  end

  # Returns the path to a FUNAMBOL80 instance adaptor dispatch.rb;
  # needs the instance identifier (gid) as argument
  def funambol80_instance_adaptor
    "funambol8.0/instances/funambol80_#{gid}/adaptor/public/dispatch.rb"
  end

  # Returns the path to a SUGARCRM52 instance adaptor dispatch.rb;
  # needs the instance identifier (gid) as argument
  def sugarcrm52_instance_adaptor
    "sugarcrm5.2/instances/sugarcrm52_#{gid}/adaptor/public/dispatch.rb"
  end

  # Returns the path to a ORANGEHRM instance adaptor dispatch.rb;
  # needs the instance identifier (gid) as argument
  def orangehrm_instance_adaptor
    "orangehrm2.2/instances/orangehrm_#{gid}/adaptor/public/dispatch.rb"
  end

  # Returns the path to a KNOWLEDGETREE instance adaptor dispatch.rb;
  # needs the instance identifier (gid) as argument
  def knowledgetree_instance_adaptor
    "knowledgetree3.5/instances/knowledgetree_#{gid}/adaptor/public/dispatch.rb"
  end

  # Returns the path to the MOODLE19 instance adaptor dispatch.rb;
  def moodle19_instance_adaptor
    "moodle1.9/instances/moodle19_#{gid}/adaptor/public/dispatch.rb"
  end

  # Runs the specified adaptor, if it exists
  def run_adaptor(adaptor)
    adaptor_abs_path = File.join(File.expand_path(ADAPTOR_ROOT + '/..'), adaptor)
    if !File.exist?(adaptor_abs_path)
	  logger.debug "Adaptor no found #{adaptor_abs_path}"
      return
    end

    Thread.new do
      $stdout.sync = true unless $stdout.sync
      unless system("ruby #{adaptor_abs_path} '#{@message}'")
        logger.error "Error calling adaptor: #{adaptor_abs_path}"
        return false
      end
      return true
    end
  end

  # Extract the gid attribute from the message
  #   Example:
  #     message = <install gid="90".../>
  #     returns "90" (String)
  def gid
    @message[/gid=\"[^\s\/>]+\"/].gsub("gid=", "").gsub("\"", "")
    # exp. reg.: extreure allo que sigui gid="alguna cosa" on 
    # alguna cosa no sigui ni \s (espai) ni / ni > 
  end

  # Returns the message type as a donwcase String
  #   Example:
  #     message: <addhostresponse .../>
  #     returns "addhostresponse"
  def message_type
    @message[1..(@message.index(/(>| |\/)/) - 1)]
  end

  # Returns the subscriber host name
  def hostname
    #From mom.yml: YAML::load(File.open("config/mom.yml"))[$mom]["subscriber"]["host"]
    $config["hostname"]
  end

end
