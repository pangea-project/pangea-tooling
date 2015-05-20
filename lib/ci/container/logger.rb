require_relative '../container'

module CI
  class ContainerLogger
    # FIXME: should insert itself into the container and run when it is
    # stopped?
    def initialize(container)
      Thread.new do
        # The log attach is threaded because
        # - attaching after start might attach to what is already stopped again in
        #   which case attach runs until timeout
        # - after start we do an explicit wait to get the correct status code so
        #   we can exit accordingly

        # This code only gets run when the socket pushes something, we cannot
        # mock this right now unfortunately.
        # :nocov:
        container.attach do |_stream, chunk|
          puts chunk
          STDOUT.flush
        end
        # :nocov:
      end
    end
  end
end
