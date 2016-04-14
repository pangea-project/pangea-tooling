require 'yaml'

require_relative 'lib/testcase'

require_relative '../kci/builder.rb'

class KCIBuilderTest < TestCase
  required_binaries %w(dch pkgkde-symbolshelper)

  REF_TIME = '20150717.1756'

  SYSTEM_BACKUP = :setup_system
  SYSTEM = :system

  def self.system_override(*args)
    fake_cmds = %w(apt-get apt add-apt-repository)
    return true if fake_cmds.include?(args[0])
    Kernel.send(SYSTEM_BACKUP, *args)
  end

  def setup
    ARGV.clear
    KCIBuilder.testing = true
    begin
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd, verbose: true)
    rescue RuntimeError
    end

    # FIXME: code copy from test_ci_build_source
    if OS::ID == 'debian'
      @release = 'sid'
      OS.instance_variable_set(:@hash, VERSION_ID: '9', ID: 'debian')
    else
      # Force ubuntu.
      @release = 'vivid'
      OS.instance_variable_set(:@hash, VERSION_ID: '15.04', ID: 'ubuntu')
    end
    alias_time

    KCI.send(:data_dir=, File.join(File.dirname(@datadir), 'fake_data'))

    Kernel.send(:alias_method, SYSTEM_BACKUP, SYSTEM)
    Kernel.send(:define_method, SYSTEM) do |*args|
      KCIBuilderTest.system_override(*args)
    end

    @setup_done = true
  end

  def teardown
    return unless @setup_done
    Kernel.send(:alias_method, SYSTEM, SYSTEM_BACKUP)

    unalias_time
    OS.reset
    KCIBuilder.testing = false
    KCI.send(:reset!)

    @setup_done = false
  end

  def alias_time
    CI::BuildVersion.send(:alias_method, :__time_orig, :time)
    CI::BuildVersion.send(:define_method, :time) { REF_TIME }
    @time_aliased = true
  end

  def unalias_time
    return unless @time_aliased
    CI::BuildVersion.send(:undef_method, :time)
    CI::BuildVersion.send(:alias_method, :time, :__time_orig)
    @time_aliased = false
  end

  def test_run
    ARGV << 'wily_unstable_extra-cmake-modules'
    ARGV << Dir.pwd
    # Expect raise as not the entire thing is covered.
    assert_raise KCIBuilder::CoverageError do
      KCIBuilder.run
    end
    # Verify source
    assert(Dir.exist?('build'))
    Dir.chdir('build')
    content = Dir.glob('*')
    assert_include(content,
                   'hello_2.10+p15.04+git20150717.1756_source.changes')
    assert_include(content, 'hello_2.10+p15.04+git20150717.1756.dsc')
    assert_include(content, 'hello_2.10+p15.04+git20150717.1756.tar.gz')
  end

  def test_bad_project
    ARGV << 'wily_extra-cmake-modules' # only two parts
    assert_raise SystemExit do
      KCIBuilder.run
    end
  end

  def symbols_data
    log_data = File.read(data('log'))
    logs = [data('log')]
    architectures_with_log = ['amd64']
    project = KCIBuilder::Project.new('wily', 'unstable', nil)
    source = CI::Source.new.tap do |s|
      s.name = nil
      s.version = nil
      s.type = nil
      s.build_version = CI::BuildVersion.new(Changelog.new(data))
    end
    [log_data, logs, architectures_with_log, project, source]
  end

  def test_update_symbols
    # Setup our remote and packaging dir
    Dir.mkdir('remote')
    Dir.chdir('remote') do
      `git init .`
      FileUtils.cp_r(data('debian'), Dir.pwd)
      `git add *`
      `git commit -a -m 'import'`
      `git checkout -b kubuntu_unstable`
    end
    `git clone --origin packaging remote packaging`

    # Actual run
    fake_home do
      KCIBuilder.update_symbols(*symbols_data)
    end

    Dir.chdir('packaging') do
      assert_equal(File.read(data('ref/libkf5akonadiagentbase5.symbols')),
                   File.read('debian/libkf5akonadiagentbase5.symbols'))
      assert_equal(File.read(data('ref/libkf5akonadicore5.symbols')),
                   File.read('debian/libkf5akonadicore5.symbols'))
    end
  end

  def test_update_symbols_retraction
    # This would fail on missing git clone, symbols files if it tried to meddle
    # with symbols actually.
    # It should return without doing anything otherwise.
    fake_home do
      KCIBuilder.update_symbols(*symbols_data)
    end
  end

  def test_update_symbols_parse_fail
    # Would fail like test_update_symbols_retraction if error condition is
    # not met.
    fake_home do
      KCIBuilder.update_symbols(*symbols_data)
    end
  end

  def test_puts_log
    FileUtils.mkpath('packaging/debian/meta')
    File.write('packaging/debian/meta/cmake-ignore', 'XCB-CURSOR')
    Dir.glob("#{data}/*/*").each do |f|
      next if File.directory?(f)
      results = KCIBuilder.lint_logs(File.read(f), updated_symbols: true)
      assert_false(results.empty?)
      if false # recording
        results_dir = "#{@datadir}/#{@method_name}/results"
        dir = File.basename(File.dirname(f))
        file = File.basename(f)
        FileUtils.mkpath("#{results_dir}/#{dir}")
        File.write("#{results_dir}/#{dir}/#{file}", results.to_yaml)
      else # verification
        results_dir = "#{@datadir}/#{@method_name}/results"
        dir = File.basename(File.dirname(f))
        file = File.basename(f)
        ref = YAML.load(File.read("#{results_dir}/#{dir}/#{file}"))
        assert_equal(ref, results, "#{dir}/#{file}")
      end
      results.each do |result|
        result.all.each do |message|
          assert_false(message.include?('symbols-file-contains-current-version-with-debian-revision'),
                       'results include symbols error but should not')
        end
      end
    end
  end

  def test_lint_cmake_no_ignore
    KCIBuilder.lint_cmake('')
  end
end
