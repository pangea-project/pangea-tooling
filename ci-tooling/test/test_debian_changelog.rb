require_relative '../lib/debian/changelog'
require_relative 'lib/testcase'

# Test debian/changelog
class DebianChangelogTest < TestCase
  def test_parse
    c = Changelog.new(data)
    assert_equal('khelpcenter', c.name)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('5.2.1-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_with_suffix
    c = Changelog.new(data)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('5.2.1~git123-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_without_suffix
    c = Changelog.new(data)
    assert_equal('', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('', c.version(Changelog::REVISION))
    assert_equal('5.2.1~git123', c.version(Changelog::ALL))
  end

  def test_with_suffix_and_epoch
    c = Changelog.new(data)
    assert_equal('4:', c.version(Changelog::EPOCH))
    assert_equal('5.2.1', c.version(Changelog::BASE))
    assert_equal('~git123', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('4:5.2.1~git123-0ubuntu1', c.version(Changelog::ALL))
  end

  def test_alphabase
    c = Changelog.new(data)
    assert_equal('4:', c.version(Changelog::EPOCH))
    assert_equal('5.2.1a', c.version(Changelog::BASE))
    assert_equal('', c.version(Changelog::BASESUFFIX))
    assert_equal('-0ubuntu1', c.version(Changelog::REVISION))
    assert_equal('4:5.2.1a-0ubuntu1', c.version(Changelog::ALL))
  end
end
