require 'docker'
require 'logger'
require 'logger/colors'

class Containment
  attr_reader :name
  attr_reader :image
  attr_reader :binds

  def initialize(name, image:, binds: [Dir.pwd])
    @name = name
    @image = image
    @binds = bindify(binds)
    @log = Logger.new(STDERR)
    @log.level = Logger::INFO
    @log.progname = self.class
    cleanup
    # TODO: finalize object and clean up container
  end

  def cleanup
    c = Docker::Container.get(@name)
    @log.info 'Cleaning up previous container.'
    c.kill!
    c.remove
    rescue Docker::Error::NotFoundError
      @log.info 'Not cleaning up, no previous container found.'
  end

  def bindify(binds)
    binds.collect do |bind|
      next bind if bind.include?(':')
      "#{bind}:#{bind}"
    end
  end

  def volumes
    v = {}
    @binds.each do |bind|
      v[bind.split(':').first] = {}
    end
    v
  end

  def contain(user_args)
    args = {
      Image: @image,
      Volumes: volumes,
      WorkingDir: Dir.pwd
    }
    args.merge!(user_args)
    c = Docker::Container.create(args)
    c.rename(@name)
    c
  end

  def attach_thread(container)
    Thread.new do
      # The log attach is threaded because
      # - attaching after start might attach to what is already stopped again in
      #   which case attach runs until timeout
      # - after start we do an explicit wait to get the correct status code so
      #   we can exit accordingly
      container.attach do |_stream, chunk|
        puts chunk
        STDOUT.flush
      end
    end
  end

  def run(args)
    c = contain(args)
    stdout_thread = attach_thread(c)
    c.start(Binds: @binds)
    status_code = c.wait.fetch('StatusCode', 1)
    c.stop
    c.remove
    status_code
  ensure
    stdout_thread.kill if defined?(stdout_thread) && !stdout_thread.nil?
  end
end
