# frozen_string_literal: true
require_relative 'lib/testcase'

require_relative '../lib/dci'

class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_release_types
    assert_equal(%w[desktop core zeronet], DCI.release_types)
  end

  def test_architectures
    assert_equal_collection(%w[amd64], DCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w[armhf arm64], DCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w[amd64 armhf arm64], DCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w[2101 next], DCI.series.keys)
    assert_equal_collection(%w[20201123 20210414], DCI.series.values)
    assert_equal('20201123', DCI.series['2101'])
    assert_equal('20210414', DCI.series['next'])

    # With sorting
    assert_equal('2001', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('next', DCI.latest_series)
  end
  # 
  # def test_type_releases
  #   assert_equal(DCI.type_releases('desktop'), %w[netrunner-desktop])
  # end
  
  def test_get_release_data
    release_data = DCI.get_release_data('netrunner-desktop')
    assert_is_a?('Struct')
    assert_equal('netrunner-desktop', release_data.name)
    assert_equal('amd64', release_data.arch)
    assert_equal(%w[netrunner extras artwork common backports netrunner-desktop netrunner-core], release_data.components)
  end
  # 
  # def test_components
  #   data = DCI.get_release_data('netrunner-desktop')
  #   assert_equal('netrunner,extras,artwork,common,backports,netrunner-desktop,netrunner-core', DCI.components(data))
  # end

  def test_arm_boards
    assert_equal(%w[c1 rock64], DCI.arm_boards)
  end
end
