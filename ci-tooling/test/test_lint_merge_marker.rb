require_relative '../lib/lint/merge_marker'
require_relative 'lib/testcase'

# Test lint merge markers
module Lint
  class MergeMarkerTest < TestCase
    def test_init
      c = Lint::MergeMarker.new
      assert_equal(Dir.pwd, c.package_directory)
      c = Lint::MergeMarker.new('/tmp')
      assert_equal('/tmp', c.package_directory)
    end

    def test_lint
      r = Lint::MergeMarker.new(data).lint
      assert(r.valid)
      assert_equal(1, r.errors.size)
      assert_equal(0, r.warnings.size)
      assert_equal(0, r.informations.size)
    end
  end
end
