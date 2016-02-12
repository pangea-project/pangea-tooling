require 'docker'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/dpkg'
require_relative '../ci/container'
require_relative '../ci/pangeaimage'

Docker.options[:read_timeout] = 0.5 * 60 * 60 # 0.5 hours
Docker.options[:write_timeout] = 0.5 * 60 * 60 # 0.5 hours
$stdout = $stderr

module MGMT
  # Class to handle Docker container deployments
  class Deployer
    Upgrade = Struct.new(:from, :to)

    attr_accessor :testing
    attr_reader :base

    # @param flavor [Symbol] ubuntu or debian base
    # @param tag [String] name of the version (vivid || unstable || wily...)
    # @param origin_tags [Array] name of alternate versions to upgrade from
    def initialize(flavor, tag, origin_tags = [])
      @base = CI::PangeaImage.new(flavor, tag)
      @origin_tags = origin_tags
      @testing = true if CI::PangeaImage.namespace.include? 'testing'
      init_logging
    end

    def init_logging
      @log = Logger.new(STDERR)

      raise 'Could not initialize logger' if @log.nil?

      Thread.new do
        # :nocov:
        Docker::Event.stream { |event| @log.debug event } unless @testing
        # :nocov:
      end
    end

    def create_base
      upgrade = nil
      base_image = "#{@base.flavor}:#{@base.tag}"
      if DPKG::HOST_ARCH == 'armhf'
        base_image = "armbuild/#{@base.flavor}:#{@base.tag}"
      end

      trying_tag = @base.tag
      begin
        @log.info "creating base docker image from #{base_image} for #{base}"
        image = Docker::Image.create(fromImage: base_image)
      rescue Docker::Error::ArgumentError, Docker::Error::NotFoundError
        error = "Failed to create Image from #{base_image}"
        raise error if @origin_tags.empty?
        puts error
        new_tag = @origin_tags.shift
        puts "Trying again with tag #{new_tag} and an upgrade..."
        base_image = base_image.gsub(trying_tag, new_tag)
        trying_tag = new_tag
        upgrade = Upgrade.new(new_tag, base.tag)
        retry
      end
      image.tag(repo: @base.repo, tag: @base.tag)
      upgrade
    end

    def deploy_inside_container(base, upgrade)
      # Take the latest image which either is the previous latest or a
      # completely prestine fork of the base ubuntu image and deploy into it.
      # FIXME use containment here probably
      @log.info "creating container from #{base}"
      cmd = ['sh', '/tooling-pending/deploy_in_container.sh']
      if upgrade
        cmd = ['sh', '/tooling-pending/deploy_upgrade_container.sh']
        cmd << upgrade.from << upgrade.to
      end
      c = CI::Container.create(Image: base.to_s,
                               WorkingDir: ENV.fetch('HOME'),
                               Cmd: cmd)
      unless @testing
        # :nocov:
        @log.info 'creating debug thread'
        Thread.new do
          c.attach do |_stream, chunk|
            puts chunk
            STDOUT.flush
          end
        end
        # :nocov:
      end

      @log.info "starting container from #{base}"
      c.start(Binds: ["#{Dir.home}/tooling-pending:/tooling-pending"])
      ret = c.wait
      status_code = ret.fetch('StatusCode', 1)
      raise "Bad return #{ret}" if status_code != 0
      c.stop!
      c
    end

    def run!
      upgrade = create_base unless Docker::Image.exist?(@base.to_s)

      c = deploy_inside_container(@base, upgrade)

      # Flatten the image by piping a tar export into a tar import.
      # Flattening essentially destroys the history of the image. By default
      # docker will however stack image revisions ontop of one another. Namely
      # if we have
      # abc and create a new image edf, edf will be an AUFS ontop of abc. While
      # this is probably useful if one doesn't commit containers repeatedly
      # for us this is pretty crap as we have massive turn around on images.
      @log.warn 'Flattening latest image by exporting and importing it.' \
                ' This can take a while.'
      require 'thwait'

      rd, wr = IO.pipe
      @i = nil

      Thread.abort_on_exception = true
      read_thread = Thread.new do
        @i = Docker::Image.import_stream do
          rd.read(1000).to_s
        end
        @log.warn 'Import complete'
        rd.close
      end
      write_thread = Thread.new do
        c.export do |chunk|
          wr.write(chunk)
        end
        @log.warn 'Export complete'
        wr.close
      end
      ThreadsWait.all_waits(read_thread, write_thread)

      c.remove
      begin
        @log.info "Deleting old image of #{@base}"
        previous_image = Docker::Image.get(@base.to_s)
        @log.info previous_image.to_s
        previous_image.delete
      rescue Docker::Error::NotFoundError
        @log.warn 'There is no previous image, must be a new build.'
      rescue Docker::Error::ConflictError
        @log.warn 'Could not remove old latest image; it is still used'
      end
      @log.info "Tagging #{@i}"
      @i.tag(repo: @base.repo, tag: @base.tag, force: true)

      # Disabled because we should not be leaking. And this has reentrancy
      # problems where another deployment can cleanup our temporary
      # container/image...
      # cleanup_dangling_things
    end
  end
end
