require 'logger'
require 'logger/colors'

module LXC
  # This actually forces the user path to be used, even for elevated calls \o/
  @elevate = false

  @log = Logger.new(STDOUT).tap do |l|
    l.level = Logger::DEBUG
    l.progname = 'LXC'
  end
  attr_reader :log
  module_function :log

  @path = `lxc-config lxc.lxcpath`.strip rescue nil
  attr_accessor :path
  module_function :path
  module_function :path=

  attr_accessor :elevate
  module_function :elevate
  module_function :elevate=

  class Container
    attr_reader :name
    attr_reader :logfile

    def initialize(name)
      @name = name
      @logfile = nil
    end

    private

    def fail(str)
      LXC.log.debug str
      Kernel.fail str
    end

    def elevator
      'sudo' if LXC.elevate
    end

    def standard_args
      args = []
      args << '-P' << LXC.path if LXC.path
      args
    end

    def cmd_string(cmd, args)
      LXC.log.info "  #{elevator} #{cmd} #{standard_args.join(' ')} #{args}"
      "#{elevator} #{cmd} #{standard_args.join(' ')} #{args}"
    end

    def run(cmd, args)
      args = args.join(' ') if args.respond_to? :join
      system(cmd_string(cmd, args))
    end

    def capture(cmd, args)
      args = args.join(' ') if args.respond_to? :join
      `#{cmd_string(cmd, args)}`
    end

    public

    def exist?
      self.exist?(@name)
    end

    def ips
      args = []
      args << '-n' << @name
      args << '--no-humanize'
      args << '--ips'
      capture('lxc-info', args)
    end

    def info
      args = []
      args << '-n' << @name
      capture('lxc-info', args)
    end

    def start
      args = []
      args << '-n' << @name
      args << '--daemon'
      args << '--logfile' << "#{Dir.pwd}/lxc.log"
      args << '--logpriority' << 'INFO'
      fail "failed to start #{@name}" unless run('lxc-start', args)
      @logfile = "#{Dir.pwd}/lxc.log"
    end

    def attach(cmd)
      args = []
      args << '-n' << @name
      args << cmd
      run('lxc-attach', args)
    end

    def stop
      fail 'failed to stop' unless run('lxc-stop', ['-n', @name])
    end

    def wait(state:, timeout:)
      state = state.upcase if state.respond_to? :upcase
      state = state.to_s
      unless run('lxc-wait', "-n #{@name} --state=#{state} --timeout=#{timeout}")
        fail "failed to wait for #{@name} to reach #{state} in #{timeout} seconds"
      end
    end

    def destroy
      fail "failed to destroy #{@name}" unless run('lxc-destroy', "-n #{@name}")
    end

    # @return [Container] new container
    def clone(new_name, snapshot: true, backingstore:)
      backingstore = backingstore.downcase if backingstore.respond_to? :downcase
      backingstore = backingstore.to_s if backingstore
      args = []
      args << '-s' if snapshot
      args << '-B' << backingstore if backingstore
      args << '-p' << LXC.path
      args << @name
      args << new_name
      unless run('lxc-clone', args)
        fail "Couldn't clone #{@name} to #{new_name}"
      end
      # FIXME: obscene hack to adjust things for elevation
      if LXC.elevate
        user = ENV['USER']
        file = "#{LXC.path}/#{new_name}/config"
        system("sudo chown $USER #{file}")
        # Rip out id mapping
        data = File.read(file)
        data.gsub!(/lxc.id_map.*$/, '')
        File.write(file, data)
      end
      Container.new(new_name)
    end
  end

  class Harness
    def initialize(container_name, base_container_name = nil)
      @container_name = container_name
      @base_container_name = base_container_name
    end

    def cleanup
      # FIXME: needs impl
      # return unless LXC::Container.exist?(@container_name)
      puts 'Cleaning up LXC'
      @container = LXC::Container.new(@container_name)
      @container.stop rescue puts 'Ignoring stop failing in cleanup'
      @container.wait(type: :stopped, timeout: 10) rescue puts 'Ignoring wait failing in cleanup'
      @container.destroy rescue puts 'Ignoring destory failing in cleanup'
      nil
    end

    def setup
      @container = LXC::Container.new(@base_container_name)
      @container = @container.clone(@container_name, snapshot: true, backingstore: :overlayfs)

      # Mount tooling and workspace directory.
      File.open("#{LXC.path}/#{@container.name}/config", 'a') do |f|
        f.write("lxc.mount.entry = #{TOOLING_PATH} #{TOOLING_PATH.gsub(/^\//, '')} none bind,create=dir\n")
        f.write("lxc.mount.entry = #{Dir.pwd} #{Dir.pwd.gsub(/^\//, '')} none bind,create=dir\n")
      end

      begin
        @container.start
        @container.wait(state: :running, timeout: TIMEOUT)
      rescue => e
        puts "Rescued exception #{e}"
        puts File.read(@container.logfile) if c.logfile
        raise e
      end

      # Running has no correlation with network-up. Make sure the container
      # got an IP address before trying to do anything with it.
      # Builds will require additional software or network access in other ways.
      has_ip = false
      TIMEOUT.times do
        if @container.ips.empty?
          has_ip = true
          break
        end
        sleep(1)
      end

      return if has_ip

      puts @container.ips
      system('free -h')
      puts @container.info
      system('brctl show lxcbr0')
      puts File.read(@container.logfile) if @container.logfile
      fail 'For some reason the container did not get an IP address. Aborting.'
    end

    def run(args)
      @container.attach(args)
    end
  end
end
