require_relative '../lib/lint/control'
require_relative 'lib/testcase'

# Test lint control
class LintControlTest < TestCase
  def test_init
    c = Lint::Control.new
    assert_equal(Dir.pwd, c.package_directory)
    c = Lint::Control.new('/tmp')
    assert_equal('/tmp', c.package_directory)
  end

  def test_invalid
    r = Lint::Control.new(data).lint
    assert(!r.valid)
  end

  def test_vcs
    r = Lint::Control.new(data).lint
    assert(r.valid)
    assert(r.errors.empty?)
    assert(r.warnings.empty?)
    assert(r.informations.empty?)
  end

  def test_vcs_missing
    r = Lint::Control.new(data).lint
    assert(r.valid)
    assert(r.errors.empty?)
    # vcs-browser missing
    # vcs-git missing
    assert_equal(2, r.warnings.size)
    assert(r.informations.empty?)
  end

  def test_vcs_partially_missing
    r = Lint::Control.new(data).lint
    assert(r.valid)
    # only vcs-git missing
    assert_equal(1, r.warnings.size)
  end
end
