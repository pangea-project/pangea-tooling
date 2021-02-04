require_relative '../lib/lint/symbols'
require_relative 'lib/testcase'

# Test lint symbols
# Because Jonathan doesn't know that we need them.
class LintSymbolsTest < TestCase
  def test_init
    c = Lint::Symbols.new
    assert_equal(Dir.pwd, c.package_directory)
    c = Lint::Symbols.new('/tmp')
    assert_equal('/tmp', c.package_directory)
  end

  def test_good
    s = Lint::Symbols.new(data).lint
    assert(s.valid)
    assert_equal([], s.errors)
    assert_equal([], s.warnings)
    assert_equal([], s.informations)
  end

  def test_arch_good
    s = Lint::Symbols.new(data).lint
    assert(s.valid)
    assert_equal([], s.errors)
    assert_equal([], s.warnings)
    assert_equal([], s.informations)
  end

  def test_missing
    s = Lint::Symbols.new(data).lint
    assert(s.valid)
    assert_equal(1, s.errors.size)
    assert_equal([], s.warnings)
    assert_equal([], s.informations)
  end
end
