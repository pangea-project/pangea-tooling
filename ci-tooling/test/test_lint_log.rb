require_relative '../lib/lint/log'
require_relative 'lib/testcase'

# Test lint lintian
class LintLogTest < TestCase
  def data
    File.read(super)
  end

  def test_lint
    rs = Lint::Log.new(data).lint
    infos = 0
    warnings = 0
    errors = 0
    rs.each do |r|
      assert(r.valid)
      infos += r.informations.size
      warnings += r.warnings.size
      errors += r.errors.size
      p r
    end
    # one I and one N from lintian
    assert_equal(2, infos)
    # two W from lintian, one cmake package
    assert_equal(3, warnings)
    # one E from lintian, two uninstalled files
    assert_equal(3, errors)
  end

  def test_invalid
    rs = Lint::Log.new('').lint
    rs.each do |r|
      assert(!r.valid)
    end
  end
end
