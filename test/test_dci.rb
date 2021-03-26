# frozen_string_literal: true
require_relative 'lib/testcase'

require_relative '../lib/dci'

class DCITest < TestCase
  def assert_equal_collection(expected, actual)
    assert_equal(expected.sort, actual.sort)
  end

  def test_types
    assert_equal_collection(%w[desktop core zeronet], DCI.types)
  end

  def test_architectures
    assert_equal_collection(%w[amd64 armhf arm64], DCI.architectures)
  end

  def test_extra_architectures
    assert_equal_collection(%w[], DCI.extra_architectures)
  end

  def test_all_architectures
    assert_equal_collection(%w[amd64 armhf arm64], DCI.all_architectures)
  end

  def test_series
    assert_equal_collection(%w[2101 next], DCI.series.keys)
    assert_equal_collection(%w[20201123 20201124], DCI.series.values)
    assert_equal('20201123', DCI.series['2101'])
    assert_equal('20201124', DCI.series['next'])

    # With sorting
    assert_equal('2101', DCI.series(sort: :ascending).keys.first)
  end

  def test_latest_series
    assert_equal('next', DCI.latest_series)
  end

  def test_arm_boards
    assert_equal(%w[c1 rock64], DCI.arm_boards)
  end
end
