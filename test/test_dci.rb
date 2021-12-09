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
    assert_equal_collection(%w[22 next buster], DCI.series.keys)
    assert_equal_collection(%w[20210510 20210410 20210110], DCI.series.values)
    assert_equal('20210510', DCI.series['22'])
    assert_equal('20210410', DCI.series['next'])

    # With sorting
    assert_equal('buster', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('22', DCI.latest_series)
  end

  def test_previous_series
    assert_equal('21.01', DCI.previous_series)
  end
  
  def test_all_image_data
    assert_is_a(DCI.all_image_data, Hash)
    assert_equal_collection(%w[desktop core zeronet zynthbox], DCI.all_image_data.keys)
    assert_equal_collection(%w[netrunner-core netrunner-core-c1], DCI.all_image_data['core'].keys)
  end
  
  def test_image_data_by_release_type
    assert_is_a(DCI.image_data_by_release_type('desktop'), Hash)
    assert_equal({"netrunner-desktop"=>
  {:releases=>{"next"=>"master", '22'=>"Netrunner/22"},
   :repo=>"https://github.com/netrunner-desktop/live-build",
   :snapshots=>["next", "22"]}}, DCI.image_data_by_release_type('desktop'))
    data = DCI.image_data_by_release_type('desktop')
    assert_equal("https://github.com/netrunner-desktop/live-build", data.fetch('netrunner-desktop')[:repo])
    assert_equal('Netrunner/22', data.fetch('netrunner-desktop')[:releases].fetch('22'))
    data = DCI.image_data_by_release_type('zynthbox')
    assert_true(data.fetch('zynthbox-rpi4')[:releases].keys.include?('buster'))
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
    release_data = DCI.get_release_data('core', 'netrunner-core-c1')
    assert_is_a(release_data, Hash)
    assert_equal('armhf', release_data['arch'])
    assert_equal(
      'netrunner extras artwork common backports c1 netrunner-core', release_data['components']
    )
  end

  def test_arm_board_by_release
    release_data = DCI.get_release_data('core', 'netrunner-core-c1')
    assert_equal('c1', DCI.arm_board_by_release(release_data))
    release_data2 = DCI.get_release_data('core', 'netrunner-core')
    assert_equal(nil, DCI.arm_board_by_release(release_data2))
    release_data = DCI.get_release_data('zeronet', 'netrunner-zeronet-rock64')
    assert_equal('rock64', DCI.arm_board_by_release(release_data))
  end

  def test_components_by_release
    release_data = DCI.get_release_data('core', 'netrunner-core-c1')
    assert_equal(["netrunner",
 "extras",
 "artwork",
 "common",
 "backports",
 "c1",
 "netrunner-core"], DCI.components_by_release(release_data))
    release_data = DCI.get_release_data('zynthbox', 'zynthbox-rpi4')
    assert_equal(['zynthbox'], DCI.components_by_release(release_data))
  end

  def test_arm_boards
    assert_equal(%w[c1 rock64 rpi4], DCI.arm_boards)
  end
  
  def test_aptly_prefix
    assert_equal('zynthbox', DCI.aptly_prefix('zynthbox'))
    assert_equal('netrunner', DCI.aptly_prefix('core'))
  end
  
  def test_series_release
    assert_equal('netrunner-desktop-22', DCI.series_release('netrunner-desktop', '22'))
    assert_equal('zynthbox-rpi4-buster', DCI.series_release('zynthbox-rpi4', 'buster'))
  end
    
  def test_arm
    assert_equal(true, DCI.arm?('netrunner-core-c1'))
    assert_true(DCI.arm?('netrunner-zeronet-rock64'))
  end

  def test_arch_by_release
    release_data = DCI.get_release_data('zynthbox', 'zynthbox-rpi4')
    assert_equal(true, 'zynthbox-rpi4'.end_with?('rpi4'))
    assert_equal('armhf', DCI.arch_by_release(release_data))
  end

end
