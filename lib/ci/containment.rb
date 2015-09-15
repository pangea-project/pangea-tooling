require 'logger'
require 'logger/colors'

require_relative 'container/ephemeral'

module CI
  class Containment
    attr_reader :name
    attr_reader :image
    attr_reader :binds
    attr_reader :privileged

    def initialize(name, image:, binds: [Dir.pwd], privileged: false)
      EphemeralContainer.assert_version

      @name = name
      @image = image
      @binds = binds
      @privileged = privileged
      @log = Logger.new(STDERR)
      @log.level = Logger::INFO
      @log.progname = self.class
      cleanup
      # TODO: finalize object and clean up container

      Signal.trap('TERM') do
        cleanup
        exit
      end
    end

    def cleanup
      c = EphemeralContainer.get(@name)
      @log.info 'Cleaning up previous container.'
      c.kill!
      c.remove
    rescue Docker::Error::NotFoundError
      @log.info 'Not cleaning up, no previous container found.'
    end

    def default_create_options
      @default_args ||= {
        # Internal
        binds: @binds,
        # Docker
        Image: @image
      }
      @default_args
    end

    def contain(user_args)
      args = default_create_options.dup
      args.merge!(user_args)
      cleanup
      c = EphemeralContainer.create(args)
      c.rename(@name)
      c
    end

    def attach_thread(container)
      Thread.new do
        # The log attach is threaded because
        # - attaching after start might attach to what is already stopped again
        #   in which case attach runs until timeout
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

    def run(args)
      c = contain(args)
      # FIXME: port to logger
      stdout_thread = attach_thread(c)
      c.start(Binds: @binds,
      Privileged: @privileged)
      status_code = c.wait.fetch('StatusCode', 1)
      c.stop
      status_code
    ensure
      stdout_thread.kill if defined?(stdout_thread) && !stdout_thread.nil?
    end
  end
end
