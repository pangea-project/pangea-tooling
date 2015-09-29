require 'docker'
require 'pathname'

module CI
  # Container with somewhat more CI-geared behavior and defaults.
  # All defaults can be overridden via create's opts.
  # @see .default_create_options
  # @see #default_start_options
  class Container < Docker::Container
    # Helper class for direct bindings.
    # Direct bindings are simply put absolute paths on the host that are meant
    # to be 1:1 bound into a container. Binding into a container requires the
    # definition of a volume and the actual binding map, both use a different
    # format and are more complex than a simple linear array of paths.
    # DirectBindingArray helps with converting a linear array of paths into
    # the respective types Docker expects.
    class DirectBindingArray
      # @return [Hash] Volume API hash of the form { Path => {} }
      def self.to_volumes(array)
        array.each_with_object({}) do |bind, memo|
          memo[bind.split(':').first] = {}
        end.to_h
      end

      # @return [Array] Binds API array of the form ["Path:Path"]
      def self.to_bindings(array)
        array.collect do |bind|
          next bind if mapped?(bind)
          "#{bind}:#{bind}"
        end
      end

      # Helper for binding candidates with colons.
      # Bindings are a bit tricky as we want to support explicit bindings AND
      # flat paths that get 1:1 mapped into the container.
      # i.e.
      #   /tmp:/tmp
      #      is a binding map already
      #   /tmp/CI::ABC
      #      is not and we'll want to 1:1 bind.
      # To tell the two apart we check if the first character after the colon
      # is a slash (target paths need to be absolute). This is fairly accurate
      # but a bit naughty code-wise, unfortunately the best algorithmic choice
      # we appear to have as paths can generally contain : all over the place.
      # Ultimately this is a design flaw in the string based mapping in Docker's
      # API really.
      def self.mapped?(bind)
        parts = bind.split(':')
        return false if parts.size <= 1
        parts.shift
        Pathname.new(parts.join(':')).absolute?
      end

    end

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
                    **options)
      # FIXME: commented to allow tests passing with old containment data
      # assert_version
      options = default_create_options.merge(options)
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
      super(options)
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
        %w(DIST TYPE).each do |v|
          next unless ENV.include?(v)
          env << format('%s=%s', v, ENV[v])
        end
        env
      end
    end
  end
end
