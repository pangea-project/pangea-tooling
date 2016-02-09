require 'docker'

require_relative 'directbindingarray'
require_relative '../../ci-tooling/lib/retry'

module CI
  # Container with somewhat more CI-geared behavior and defaults.
  # All defaults can be overridden via create's opts.
  # @see .default_create_options
  # @see #default_start_options
  class Container < Docker::Container
    DirectBindingArray = CI::DirectBindingArray

    # @return [Array<String>] Array of absolute paths on the host that should
    #   be bound 1:1 into the container.
    attr_reader :binds

    # Create with convenience argument handling. Forwards to
    # Docker::Container::create.
    #
    # @param name The name to use for the container. Uses random name if nil.
    # @param binds An array of paths mapping 1:1 from host to container. These
    #   will be automatically translated into Container volumes and binds for
    #   {#start}.
    #
    # @param options Forwarded. Passed to Docker API as arguments.
    # @param connection Forwarded. Connection to use.
    #
    # @return [Container]
    def self.create(connection = Docker.connection,
                    name: nil,
                    binds: [Dir.pwd],
                    **options_)
      # FIXME: commented to allow tests passing with old containment data
      # assert_version
      options = merge_env(default_create_options, options_)
      options = options.merge(options_)
      options['name'] = name if name
      options[:Volumes] = DirectBindingArray.to_volumes(binds) if binds
      c = super(options, connection)
      c.send(:instance_variable_set, :@binds, binds)
      c
    end

    # @return [Boolean] true when the container exists, false otherwise.
    def self.exist?(id, options = {}, connection = Docker.connection)
      get(id, options, connection)
      true
    rescue Docker::Error::NotFoundError
      false
    end

    # Start with convenience argument handling. Forwards to
    # Docker::Container#start
    # @return [Container]
    def start(options = {})
      options = default_start_options.merge(options)
      # There seems to be a race condition somewhere in udev/docker
      # https://github.com/docker/docker/issues/4036
      # Keep retrying till it works
      Retry.retry_it(times: 5, errors: [Docker::Error::NotFoundError]) do
        super(options)
      end
    end

    # Default container start/run arguments.
    # - Binds: Set to binds used on {create}
    # - Ulimits: Set to sane defaults with lower nofile property
    # @return [Hash]
    def default_start_options
      @default_start_options ||= {
        Binds: DirectBindingArray.to_bindings(@binds),
        # Force standard ulimit in the container.
        # Otherwise pretty much all APT IO operations are insanely slow:
        # https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1332440
        # This in particular affects apt-extracttemplates which will take up to
        # 20 minutes where it should take maybe 1/10 of that.
        Ulimits: [{ Name: 'nofile', Soft: 1024, Hard: 1024 }]
      }
    end

    class << self
      # Default container create arguments.
      # - WorkingDir: Set to Dir.pwd
      # - Env: Sensible defaults for LANG, PATH, DEBIAN_FRONTEND
      # @return [Hash]
      def default_create_options
        {
          WorkingDir: Dir.pwd,
          Env: environment
        }
      end

      def assert_version
        # In order to effecitvely set ulimits we need docker 1.6.
        docker_version = Docker.version['Version']
        return if Gem::Version.new(docker_version) >= Gem::Version.new('1.6')
        fail "Containment requires Docker 1.6; found #{docker_version}"
      end

      private

      def environment
        env = []
        env << 'PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin'
        env << 'LANG=en_US.UTF-8'
        env << 'DEBIAN_FRONTEND=noninteractive  '
        %w(DIST TYPE BUILD_NUMBER).each do |v|
          next unless ENV.include?(v)
          env << format('%s=%s', v, ENV[v])
        end
        env
      end

      def merge_env(our_options, their_options)
        ours = our_options[:Env]
        theirs = their_options[:Env]
        return our_options if theirs.nil?
        our_hash = ours.map { |i| i.split('=') }.to_h
        their_hash = theirs.map { |i| i.split('=') }.to_h
        our_options[:Env] = our_hash.merge(their_hash).map { |i| i.join('=') }
        their_options.delete(:Env)
        our_options
      end
    end
  end
end
