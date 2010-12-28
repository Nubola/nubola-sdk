# TODO - NOTE
# This is an example implementation
# It just logs the message

class ApplicationExampleAdaptorSimple < Adaptation::Adaptor

  def process(message)
    super message
    logger.info "Update of type '#{message_type}' for gid '#{gid}'"
    logger.info "message = #{message.to_xml}"
  end

end
