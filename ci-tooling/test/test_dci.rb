require_relative 'lib/testcase'
# Require kci through the kci/lib symlink to make sure path resolution works
# even with the changed relativity towards data/.
# i.e. ../data/kci.yaml is ../../data/kci.yaml within that symlink context
require_relative '../kci/lib/dci'

# Test kci
class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_types
    assert_equal_collection(%w(stable), DCI.types)
  end

  def test_architectures
    assert_equal_collection(%w(amd64 armhf), DCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w(), DCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w(amd64 armhf), DCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w(stable), DCI.series.keys)
    assert_equal_collection(%w(8), DCI.series.values)
    assert_equal('8', DCI.series['stable'])

    # With sorting
    assert_equal('stable', DCI.series(sort: :ascending).keys.first)
    assert_equal('stable', DCI.series(sort: :descending).keys.first)
  end

  def test_latest_series
    assert_equal('stable', DCI.latest_series)
  end
end
