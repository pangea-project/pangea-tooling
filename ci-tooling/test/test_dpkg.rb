require_relative '../lib/dpkg'
require_relative 'lib/assert_backtick'
require_relative 'lib/testcase'

# Test DPKG
class DPKGTest < TestCase
  prepend AssertBacktick

  def test_architectures
    assert_backtick('dpkg-architecture -qDEB_BUILD_ARCH') do
      DPKG::BUILD_ARCH
    end

    assert_backtick('dpkg-architecture -qDEB_BUBU') do
      DPKG::BUBU
    end
  end

  def test_listing
    assert_backtick('dpkg -L abc') do
      DPKG.list('abc')
    end
  end
end
