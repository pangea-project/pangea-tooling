require_relative '../lib/lint/result'
require_relative 'lib/testcase'

# Test lint result
class LintResultTest < TestCase
  # Things other than logger are tested implicitly through higher level test.
  def test_logger_init
    r = Lint::ResultLogger.new(nil)
    assert(r.results.empty?)
  end

  def test_logger
    r = Lint::Result.new
    r.valid = true
    r.errors << 'error'
    r.warnings << 'warning'
    r.informations << 'info'

    l = Lint::ResultLogger.new(r)
    assert(l.results.is_a?(Array))
    assert_equal(1, l.results.size)
    assert_equal(r, l.results.first)
    l.log
  end

  def test_merge
    r1 = Lint::Result.new
    r1.valid = true
    r1.errors << 'error'
    r1.warnings << 'warning'
    r1.informations << 'info'

    r2 = Lint::Result.new
    r2.valid = false
    r2.errors << 'error2'
    r2.warnings << 'warning2'
    r2.informations << 'info2'

    r3 = Lint::Result.new
    r3.merge!(r1)
    r3.merge!(r2)
    assert(r3.valid)
    assert_equal(r1.errors + r2.errors, r3.errors)
    assert_equal(r1.warnings + r2.warnings, r3.warnings)
    assert_equal(r1.informations + r2.informations, r3.informations)
  end

  def test_all
    r = Lint::Result.new
    r.valid = true
    r.errors << 'error1' << 'error2'
    r.warnings << 'warning1'
    r.informations << 'info1' << 'info2'
    assert_equal(%w(error1 error2 warning1 info1 info2), r.all)
  end

  def test_equalequal
    r1 = Lint::Result.new
    r1.valid = true
    r1.errors << 'error1' << 'error2'
    r1.warnings << 'warning1'
    r1.informations << 'info1' << 'info2'

    r2 = Lint::Result.new
    r2.valid = true
    r2.errors << 'error1' << 'error2'
    r2.warnings << 'warning1'
    r2.informations << 'info1' << 'info2'

    assert(r1 == r2, 'r1 not same as r2')
    assert(r2 == r1, 'r2 not same as r1')
  end
end
