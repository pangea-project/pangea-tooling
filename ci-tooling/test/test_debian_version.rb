require_relative '../lib/debian/version'
require_relative 'lib/testcase'

# Test debian version
class DebianVersionTest < TestCase
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
end
