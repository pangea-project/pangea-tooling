require_relative 'lib/testcase'

require_relative '../lib/dci'

class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_types
    assert_equal_collection(%w(release), DCI.types)
  end

  def test_architectures
    assert_equal_collection(%w(arm64 amd64 armhf), DCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w(), DCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w(arm64 amd64 armhf), DCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w(1710 1801 1803 backports), DCI.series.keys)
    assert_equal_collection(%w(20170904 20180115 20180315 20180316), DCI.series.values)
    assert_equal('20170904', DCI.series['1710'])
    assert_equal('20180115', DCI.series['1801'])
    assert_equal('20180315', DCI.series['1803'])
    assert_equal('20180316', DCI.series['backports'])

    # With sorting
    assert_equal('1710', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('backports', DCI.latest_series)
  end
end
