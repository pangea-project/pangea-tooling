require_relative '../lib/debian/control'
require_relative 'lib/testcase'

# Test debian/source/format
class DebianControlFormatTest < TestCase
  def setup
    Dir.chdir(@datadir)
  end

  def test_parse
    assert_nothing_raised do
      c = DebianControl.new
      c.parse!
    end
  end

  def test_key
    c = DebianControl.new
    c.parse!
    assert_not_nil(c.source.key?('build-depends'))
  end

  def test_value
    c = DebianControl.new
    c.parse!
    assert_equal(1, c.source['build-depends'].size)
    assert_nil(c.source.fetch('magic', nil))
  end

  def test_no_build_deps
    Dir.chdir(data)
    c = DebianControl.new
    c.parse!
    assert_equal(0, c.source.fetch('build-depends', []).size)
  end
end
