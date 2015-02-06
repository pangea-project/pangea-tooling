require 'test/unit'
require 'tmpdir'

# require_relative '../kci/merger'


module LXC
  @config_path = nil

  attr_accessor :config_path
  module_function :config_path
  module_function :config_path=

  class Container
    attr_reader :name
    attr_reader :logfile

    def iniitalize(name)
      @name = name
      @logfile = nil
    end

    def standard_args
      args = []
      args << '-P' << LXC.config_path if LXC.config_patha
    end

    def run(cmd, args)
      args = args.join(' ') if args.respond_to? :join
      system("#{cmd} #{standard_args.join(' ')} #{args}")
    end

    def capture(cmd, args)
      args = args.join(' ') if args.respond_to? :join
      `#{cmd} #{standard_args.join(' ')} #{args}`
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
      fail 'failed to stop' unless system("lxc-stop -n #{@name}")
    end

    def wait(state:, timeout:)
      state = state.upcase if state.respond_to? :upcase
      state = state.to_s
      unless run('lxc-wait', "-n #{@name} --state=#{state} --timeout=#{timeout}")
        fail "failed to wait for #{@name} to reach #{state} in #{timeout} seconds"
      end
    end

    def destroy
      fail "failed to destory #{@name}" unless run('lxc-destory', "-n #{@name}")
    end

    # @return [Container] new container
    def clone(new_name, snapshot: true, backingstore:)
      backingstore = backingstore.downcase if backingstore.respond_to? :downcase
      backingstore = backingstore.to_s if backingstore
      args = []
      args << '-s' if snapshot
      args << '-B' << backingstore if backingstore
      args << @name
      args << new_name
      unless run('lxc-clone', args)
        fail "Couldn't clone #{@name} to #{new_name}"
      end
      Container.new(new_name, standard_args)
    end
  end
end

class LxcHarnessTest < Test::Unit::TestCase
  self.test_order = :defined

  def setup
    @tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir('/')
    FileUtils.rm_rf(@tmpdir)
  end

  def test_config_path
    assert_equal(nil, LXC.config_path)
    LXC.config_path = '/yolo'
    assert_equal('/yolo', LXC.config_path)
  end
end
