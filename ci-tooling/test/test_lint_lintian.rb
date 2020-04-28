require_relative '../lib/lint/log/lintian'
require_relative 'lib/testcase'

# Test lint lintian
class LintLintianTest < TestCase
  def test_lint
    r = Lint::Log::Lintian.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(2, r.informations.size)
    assert_equal(2, r.warnings.size)
    assert_equal(2, r.errors.size)
  end

  def test_invalid
    r = Lint::Log::Lintian.new.lint(File.read(data))
    assert(!r.valid)
  end
end
