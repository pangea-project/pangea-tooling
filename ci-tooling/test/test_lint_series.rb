require_relative '../lib/lint/series'
require_relative 'lib/testcase'

# Test lint series
class LintSeriesTest < TestCase
  def test_init
    s = Lint::Series.new
    assert_equal(Dir.pwd, s.package_directory)
    s = Lint::Series.new('/tmp')
    assert_equal('/tmp', s.package_directory)
  end

  def test_missing
    s = Lint::Series.new(data).lint
    assert(s.valid)
    assert_equal([], s.errors)
    assert_equal(1, s.warnings.size)
    assert_equal([], s.informations)
  end

  def test_complete
    s = Lint::Series.new(data).lint
    assert(s.valid)
    assert_equal([], s.errors)
    assert_equal([], s.warnings)
    assert_equal([], s.informations)
  end

  def test_ignore
    # Has two missing but only one is reported as such.
    s = Lint::Series.new(data).lint
    assert(s.valid)
    assert_equal([], s.errors)
    assert_equal(1, s.warnings.size)
    assert_equal([], s.informations)
  end
end
