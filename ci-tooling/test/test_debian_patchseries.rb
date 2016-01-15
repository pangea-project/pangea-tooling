require_relative '../lib/debian/patchseries'
require_relative 'lib/testcase'

# Test debian patch series
class DebianPatchSeriesTest < TestCase
  def test_read
    s = Debian::PatchSeries.new(data)
    assert_equal(4, s.patches.size)
    %w(a.patch b.patch above-is-garbage.patch level.patch).each do |f|
      assert_include(s.patches, f, "patch #{f} should be in series")
    end
  end

  def test_read_from_name
    s = Debian::PatchSeries.new(data, 'yolo')
    assert_equal(4, s.patches.size)
    %w(a.patch b.patch above-is-garbage.patch level.patch).each do |f|
      assert_include(s.patches, f, "patch #{f} should be in series")
    end
  end
end
