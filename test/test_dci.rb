# frozen_string_literal: true
require_relative 'lib/testcase'

require_relative '../lib/dci'

class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_release_types
    assert_equal(%w[desktop core zeronet zynthbox], DCI.release_types)
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
    assert_equal_collection(%w[2101 22 next buster], DCI.series.keys)
    assert_equal_collection(%w[20210109 20210510 20210610 20210110], DCI.series.values)
    assert_equal('20210510', DCI.series['22'])
    assert_equal('20210610', DCI.series['next'])

    # With sorting
    assert_equal('2101', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('next', DCI.latest_series)
  end

  def test_releases_for_type
    assert_equal(%w[netrunner-desktop], DCI.releases_for_type('desktop'))
    assert_equal(%w[netrunner-core netrunner-core-c1], DCI.releases_for_type('core'))
    assert_is_a(DCI.releases_for_type('desktop'), Array)
  end

  def test_release_data_for_type
    assert_equal(
      { 'netrunner-core' =>
          { 'arch' => 'amd64',
            'components' => 'netrunner extras artwork common backports netrunner-core' },
        'netrunner-core-c1' =>
           { 'arch' => 'armhf',
             'arm_board' => 'c1',
             'components' => 'netrunner extras artwork common backports c1 netrunner-core' } },
      DCI.release_data_for_type('core')
    )
  end

  def test_get_release_data
    release_data = DCI.get_release_data('desktop', 'netrunner-desktop')
    assert_is_a(release_data, Hash)
    assert_equal('amd64', release_data['arch'])
    assert_equal(
      'netrunner extras artwork common backports netrunner-core netrunner-desktop', release_data['components']
    )
  end

  def test_arm_board_by_release
    release_data = DCI.get_release_data('core', 'netrunner-core-c1')
    assert_equal('c1', DCI.arm_board_by_release(release_data))
    release_data2 = DCI.get_release_data('core', 'netrunner-core')
    assert_equal(nil, DCI.arm_board_by_release(release_data2))
  end
  
  def test_components_by_release
    release_data = DCI.get_release_data('core', 'netrunner-core-c1')
    assert_equal('netrunner extras artwork common backports c1 netrunner-core', DCI.components_by_release(release_data))
  end

  def test_arm_boards
    assert_equal(%w[c1 rock64 rpi4], DCI.arm_boards)
  end

  def test_arm
    assert_equal(true, DCI.arm?('netrunner-core-c1'))
  end
end
