require_relative 'lib/testcase'
# Require kci through the kci/lib symlink to make sure path resolution works
# even with the changed relativity towards data/.
# i.e. ../data/kci.yaml is ../../data/kci.yaml within that symlink context
require_relative '../kci/lib/kci'

# Test kci
class KCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_types
    assert_equal_collection(%w(stable unstable), KCI.types)
  end

  def test_architectures
    assert_equal_collection(%w(amd64 i386), KCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w(armhf), KCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w(amd64 i386 armhf), KCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w(xenial wily), KCI.series.keys)
    assert_equal_collection(%w(16.04 15.10), KCI.series.values)
    assert_equal('16.04', KCI.series['xenial'])
    assert_equal('15.10', KCI.series['wily'])

    # With sorting
    assert_equal('wily', KCI.series(sort: :ascending).keys.first)
    assert_equal('xenial', KCI.series(sort: :descending).keys.first)
  end

  def test_latest_series
    assert_equal('xenial', KCI.latest_series)
  end
end
