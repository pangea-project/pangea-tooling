require 'logger'
require 'logger/colors'

require_relative 'container/ephemeral'
require_relative 'pangeaimage'

module CI
  class Containment
    TRAP_SIGNALS = %w(EXIT HUP INT QUIT TERM)

    attr_reader :name
    attr_reader :image
    attr_reader :binds
    attr_reader :privileged

    def initialize(name, image:, binds: [Dir.pwd], privileged: false)
      EphemeralContainer.assert_version

      @name = name
      @image = image # Can be a PangeaImage
      @binds = binds
      @privileged = privileged
      @log = Logger.new(STDERR)
      @log.level = Logger::INFO
      @log.progname = self.class
      cleanup
      # TODO: finalize object and clean up container
      trap!
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
        Image: @image.to_str # Can be a PangeaImage instance
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
      return rescued_start(c)
    ensure
      stdout_thread.kill if defined?(stdout_thread) && !stdout_thread.nil?
    end

    private

    def chown_handler
      return @chown_handler if defined?(@chown_handler)
      return nil if @privileged
      binds_ = @binds.dup # Remove from object context so Proc can be a closure.
      @chown_handler = proc do
        chown_container =
          CI::Containment.new("#{@name}_chown", image: @image, binds: binds_)
        ec = chown_container.run("chown -R 100000:120 #{binds_.join(' ')}")
        STDERR.puts 'Chowning completed' if ec
        STDERR.puts 'Chowning failed!' unless ec
      end
    end

    def trap!
      TRAP_SIGNALS.each do |signal|
        previous = Signal.trap(signal, nil)
        Signal.trap(signal) do
          cleanup
          chown_handler.call if chown_handler
          previous.call if previous
        end
      end
    end

    def rescued_start(c)
      c.start(Privileged: @privileged)
      status_code = c.wait.fetch('StatusCode', 1)
      c.stop
      status_code
    rescue Docker::Error::NotFoundError => e
      @log.error 'Failed to create container!'
      @log.error e.to_s
      return 1
    end
  end
end
