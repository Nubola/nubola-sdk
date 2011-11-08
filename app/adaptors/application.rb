# This adapter is used by bin/subscribe 

require 'open3'

class ApplicationAdaptor < Adaptation::Adaptor

  cattr_accessor :options

  def process(message)
    super message

    logger.debug "Update of type '#{message_type}' for gid '#{gid}'"

    if options && options.exec
      logger.debug "exec '#{options.exec}' ... "
      Open3.popen3(options.exec) do |stdin, stdout, stderr|
        stdin.puts message.original
        stdin.close
        stdout.each do |l|
          logger.debug "output = #{l}"
        end
      end
    end
  end

  def cif
    @message.cif
  end

end
