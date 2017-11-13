require_relative '../lib/debian/version'
require_relative 'lib/testcase'

# Test debian version
class DebianVersionTest < TestCase
  required_binaries(%w[dpkg])

  def test_native
    s = '5.0'
    v = Debian::Version.new(s)
    assert_equal(nil, v.epoch)
    assert_equal('5.0', v.upstream)
    assert_equal(nil, v.revision)
  end

  def test_native_epoch
    s = '1:5.0'
    v = Debian::Version.new(s)
    assert_equal('1', v.epoch)
    assert_equal('5.0', v.upstream)
    assert_equal(nil, v.revision)
  end

  def test_full
    s = '1:5.0-0ubuntu1'
    v = Debian::Version.new(s)
    assert_equal('1', v.epoch)
    assert_equal('5.0', v.upstream)
    assert_equal('0ubuntu1', v.revision)
  end

  def assert_v_greater(a, b, message = nil)
    message = build_message(message,
                            '<?> is not greater than <?>.',
                            a.full, b.full)
    assert_block message do
      1 == (a <=> b)
    end
  end

  def assert_v_lower(a, b, message = nil)
    message = build_message(message,
                            '<?> is not lower than <?>.',
                            a.full, b.full)
    assert_block message do
      -1 == (a <=> b)
    end
  end

  def assert_v_equal(a, b, message = nil)
    message = build_message(message,
                            '<?> is not equal to <?>.',
                            a.full, b.full)
    assert_block message do
      0 == (a <=> b)
    end
  end

  def assert_v_flip(x, y)
    assert_v_greater(x, y)
    assert_v_lower(y, x)
  end

  def test_greater_and_lower
    assert_v_flip(Debian::Version.new('1:0'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1.1'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1+'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1.1~'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('2~'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1-1'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1-0.1'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1-0+'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('1-1~'), Debian::Version.new('1'))
    assert_v_flip(Debian::Version.new('0:1-0.'), Debian::Version.new('1'))
  end

  def test_equal
    assert_v_equal(Debian::Version.new('1-0'), Debian::Version.new('1'))
    assert_v_equal(Debian::Version.new('1'), Debian::Version.new('1'))
    assert_v_equal(Debian::Version.new('0:1'), Debian::Version.new('1'))
    assert_v_equal(Debian::Version.new('0:1-0'), Debian::Version.new('1'))
    assert_v_equal(Debian::Version.new('0:1-0'), Debian::Version.new('1'))
  end

  def test_manipulation
    v = Debian::Version.new('5:1.0-1')
    assert_equal('5:1.0-1', v.to_s)
    assert_equal('5:1.0-1', v.full)
    v.upstream = '2.0'
    assert_equal('5:2.0-1', v.to_s)
    assert_equal('5:2.0-1', v.full)
  end

  def test_comparable
    # Implements Comparable module.
    assert(Debian::Version.new('1.0') > Debian::Version.new('0.1'))
  end

  def test_dpkg_installed
    # Make sure we can find dpkg when we need to.
    # This test assumes dpkg is actually available in $PATH which we require
    # for this entire testcase anyway per `required_binaries`.
    ENV.delete('PANGEA_UNDER_TEST')

    Debian::Version.dpkg_installed = nil
    Debian::Version.new('1.0') > Debian::Version.new('0.1')
  ensure
    Debian::Version.dpkg_installed = nil
  end

  def test_dpkg_not_installed
    # As above but expect failure as we have no dpkg available in $PATH
    ENV.delete('PANGEA_UNDER_TEST')

    FileUtils.ln_s('/usr/bin/which', '.', verbose: true)
    ENV['PATH'] = Dir.pwd

    Debian::Version.dpkg_installed = nil
    assert_raises do
      Debian::Version.new('1.0') > Debian::Version.new('0.1')
    end
  ensure
    Debian::Version.dpkg_installed = nil
  end
end
