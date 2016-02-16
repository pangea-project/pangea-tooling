require 'fileutils'
require 'vcr'

require_relative '../lib/qml_dependency_verifier'
require_relative 'lib/assert_backtick'
require_relative 'lib/assert_system'
require_relative 'lib/testcase'

# Test qml dep verifier
class QMLDependencyVerifierTest < TestCase
  prepend AssertBacktick
  prepend AssertSystem

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
    LSB.instance_variable_set(:@hash, DISTRIB_CODENAME: 'vivid')

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)

    reset_child_status! # Make sure $? is fine before we start!
  end

  def teardown
    VCR.eject_cassette(File.basename(__FILE__, '.rb'))
    LSB.reset
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

  def test_source
    source = QMLDependencyVerifier.new.source
    assert_equal(ref['name'], source.name)
    assert_equal(ref['version'], source.version)
    assert_equal(ref['type'], source.type)
  end

  def test_binaries
    assert_backtick(['dpkg-architecture -qDEB_HOST_ARCH']) do
      assert_equal(ref, QMLDependencyVerifier.new.binaries)
    end
  end

  def test_add_ppa
    assert_system([%w(apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true update),
                   %w(apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true install software-properties-common),
                   %w(add-apt-repository -y ppa:kubuntu-ci/unstable),
                   %w(apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true update)]) do
      QMLDependencyVerifier.new.add_ppa
    end
  end

  def test_missing_modules
    # Make sure our ignore is in place in the data dir.
    # NB: this testcase is chdir in the @datadir not the @tmpdir!
    assert(File.exist?('packaging/debian/plasma-widgets-addons.qml-ignore'))
    # Prepare sequences, divert search path and run verification.
    const_reset(QML, :SEARCH_PATHS, [File.join(data, 'qml')])
    system_sequence = JSON.parse(File.read(data('system_sequence')))
    backtick_sequence = JSON.parse(File.read(data('backtick_sequence')))
    assert_system(system_sequence) do
      assert_backtick(backtick_sequence) do
        missing = QMLDependencyVerifier.new.missing_modules
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
  end

  def backtick_intercept(args)
    case args[0]
    when 'dpkg-architecture -qDEB_HOST_ARCH'
      return 'amd64'
    when 'dpkg -L plasma-widgets-addons'
      return data('main.qml')
    end
    return '' if args[0].start_with?('dpkg -L ')
  end
end
