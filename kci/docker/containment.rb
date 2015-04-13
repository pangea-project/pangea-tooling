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
      WorkingDir: Dir.pwd,
      Env: environment
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
    stdout_thread = attach_thread(c)
    c.start(Binds: @binds)
    status_code = c.wait.fetch('StatusCode', 1)
    rescued_stop(c)
    status_code
  ensure
    stdout_thread.kill if defined?(stdout_thread) && !stdout_thread.nil?
  end

  private

  def environment
    env = ['PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin']
    %w(DIST TYPE).each do |v|
      next unless ENV.include?(v)
      env << format('%s=%s', v, ENV[v])
    end
    env
  end

  def rescued_stop(container)
    # https://github.com/docker/docker/issues/9665
    # Possibly related as well:
    # https://github.com/docker/docker/issues/7636
    # Apparently the AUFS backend is a bit meh and craps out randomly when
    # removing a container. To prevent this from making a build fail two things
    # happen here:
    # 1. sleep 5 seconds before trying to kill. This avoids an apparently also
    #    existing timing issue which might or might not be the root of this.
    # 2. catch server errors from remove and turn them into logable offences
    #    without impact. Since this method is only supposed to be called from
    #    {run} there is no strict requirement for the container to be actually
    #    removed as a subsequent containment instance will attempt to tear it
    #    down anyway. Which might then be fatal, but given the 5 second sleep
    #    and additional time spent doing other things it is unlikely that this
    #    would happen. Should it happen though we still want it to be fatal
    #    though as the assumption is that a containment always is clean which
    #    we couldn't ensure if a previous container can not be removed.
    container.stop
    container.kill!
    sleep 5
    begin
      container.remove
    # :nocov:
    rescue Docker::Error::ServerError => e
      @log.error e
    end
    # :nocov:
  end
end
