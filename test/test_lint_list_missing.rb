require_relative '../lib/lint/log/list_missing'
require_relative 'lib/testcase'

# Test lint lintian
class LintListMissingTest < TestCase
  def test_lint
    r = Lint::Log::ListMissing.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(0, r.warnings.size)
    assert_equal(2, r.errors.size)
  end

  def test_invalid
    r = Lint::Log::ListMissing.new.lint('')
    assert(!r.valid)
  end
end
