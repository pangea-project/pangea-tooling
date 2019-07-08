require_relative 'lib/testcase'

require_relative '../lib/dci'

class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_types
    assert_equal_collection(%w(desktop backports), DCI.types)
  end

  def test_architectures
    assert_equal_collection(%w(amd64), DCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w(), DCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w(amd64), DCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w(1908 next), DCI.series.keys)
    assert_equal_collection(%w(20190630 20190701), DCI.series.values)
    assert_equal('20190630', DCI.series['1908'])
    assert_equal('20190701', DCI.series['next'])

    # With sorting
    assert_equal('1908', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('next', DCI.latest_series)
  end
end
