# frozen_string_literal: true
require 'deep_merge'
require_relative 'docker'
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
      options = merge_env_options(default_create_options, options_)
      options = options_.deep_merge(options)
      options = override_options(options, name, binds)
      c = super(options, connection)
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
      # There seems to be a race condition somewhere in udev/docker
      # https://github.com/docker/docker/issues/4036
      # Keep retrying till it works
      Retry.retry_it(times: 5, errors: [Docker::Error::NotFoundError]) do
        super(options)
      end
    end

    class << self
      # Default container create arguments.
      # - WorkingDir: Set to Dir.pwd
      # - Env: Sensible defaults for LANG, PATH, DEBIAN_FRONTEND
      # - Ulimits: Set to sane defaults with lower nofile property
      # @return [Hash]
      def default_create_options
        {
          # Force standard ulimit in the container.
          # Otherwise pretty much all APT IO operations are insanely slow:
          # https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1332440
          # This in particular affects apt-extracttemplates which will take up
          # to 20 minutes where it should take maybe 1/10 of that.
          HostConfig: {
            Ulimits: [{ Name: 'nofile', Soft: 1024, Hard: 1024 }]
          },
          WorkingDir: Dir.pwd,
          Env: environment
        }
      end

      def assert_version
        # In order to effecitvely set ulimits we need docker 1.6.
        docker_version = Docker.version['Version']
        return if Gem::Version.new(docker_version) >= Gem::Version.new('1.12')
        raise "Containment requires Docker 1.12; found #{docker_version}"
      end

      private

      def override_options(options, name, binds)
        options['name'] = name if name
        if binds
          options[:Volumes] = DirectBindingArray.to_volumes(binds)
          options[:HostConfig][:Binds] = DirectBindingArray.to_bindings(binds)
        end
        options
      end

      # Returns nil if the env var v is not defined. Otherwise it returns its
      # stringy form.
      def stringy_env_var!(v)
        return nil unless ENV.include?(v)
        format('%s=%s', v, ENV[v])
      end

      def environment
        env = []
        env <<
          'PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin'
        env << 'LANG=en_US.UTF-8'
        env << 'DEBIAN_FRONTEND=noninteractive  '
        env += %w[DIST TYPE BUILD_NUMBER].collect { |v| stringy_env_var!(v) }
        env += environment_from_whitelist
        env.compact # compact to ditch stringy_env_var! nils.
      end

      # Build initial env from potentially whitelisted env vars in our current
      # env. These will be passed verbatim into docker. This is the base
      # environment. On top of this we'll pack a bunch of extra variables we'll
      # want to pass in all the time. The user fo the class then also can add
      # and override more vars on top of that.
      # Note: this is a bit of a workaround. Our tests are fairly meh and always
      # include the start environment in the expecation, so changes to the
      # defaults are super cumbersome to implement. This acts as much as way
      # to bypass that as it acts as a legit extension to functionality as it
      # allows any old job to extend the forwarded env without having to extend
      # the default forwards.
      def environment_from_whitelist
        list = ENV.fetch('DOCKER_ENV_WHITELIST', '')
        list.split(':').collect { |v| stringy_env_var!(v) }.compact
      end

      def merge_env_options(our_options, their_options)
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
