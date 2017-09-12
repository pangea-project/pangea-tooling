require 'fileutils'
require 'vcr'

require_relative '../lib/qml_dependency_verifier'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test qml dep verifier
class QMLDependencyVerifierTest < TestCase
  def const_reset(klass, symbol, obj)
    klass.send(:remove_const, symbol)
    klass.const_set(symbol, obj)
  end

  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :webmock
    end
    VCR.insert_cassette(File.basename(__FILE__, '.rb'))

    Dir.chdir(@datadir)

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)

    reset_child_status! # Make sure $? is fine before we start!

    # Let all backtick or system calls that are not expected fall into
    # an error trap!
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never

    # Default stub architecture as amd64
    Object.any_instance.stubs(:`)
          .with('dpkg-architecture -qDEB_HOST_ARCH')
          .returns('amd64')

    # We'll temporary mark packages as !auto, mock this entire thing as we'll
    # not need this for testing.
    Apt::Mark.stubs(:tmpmark).yields
  end

  def teardown
    VCR.eject_cassette(File.basename(__FILE__, '.rb'))
  end

  def data(path = nil)
    index = 0
    caller = ''
    until caller.start_with?('test_')
      caller = caller_locations(index, 1)[0].label
      index += 1
    end
    File.join(*[@datadir, caller, path].compact)
  end

  def ref_path
    "#{data}.ref"
  end

  def ref
    JSON.parse(File.read(ref_path))
  end

  def test_missing_modules
    # Make sure our ignore is in place in the data dir.
    # NB: this testcase is chdir in the @datadir not the @tmpdir!
    assert(File.exist?('packaging/debian/plasma-widgets-addons.qml-ignore'))
    # Prepare sequences, divert search path and run verification.
    const_reset(QML, :SEARCH_PATHS, [File.join(data, 'qml')])

    system_sequence = sequence('system')
    backtick_sequence = sequence('backtick')
    JSON.parse(File.read(data('system_sequence'))).each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end
    JSON.parse(File.read(data('backtick_sequence'))).each do |cmd|
      Object.any_instance.expects(:`)
            .with(*cmd)
            .returns('')
            .in_sequence(backtick_sequence)
    end
    Object.any_instance.stubs(:`)
          .with('dpkg -L plasma-widgets-addons')
          .returns(data('main.qml'))

    repo = mock('repo')
    repo.stubs(:add).returns(true)
    repo.stubs(:remove).returns(true)
    repo.stubs(:binaries).returns({"kwin-addons"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "plasma-dataengines-addons"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "plasma-runners-addons"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "plasma-wallpapers-addons"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "plasma-widget-kimpanel"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "plasma-widgets-addons"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0", "kdeplasma-addons-data"=>"4:5.2.1+git20150316.1204+15.04-0ubuntu0"})

    missing = QMLDependencyVerifier.new(repo).missing_modules
    assert_equal(1, missing.size, 'More things missing than expected' \
                                  " #{missing}")

    assert(missing.key?('plasma-widgets-addons'))
    missing = missing.fetch('plasma-widgets-addons')
    assert_equal(1, missing.size, 'More modules missing than expected' \
                 " #{missing}")

    missing = missing.first
    assert_equal('QtWebKit', missing.identifier)
  end
end
