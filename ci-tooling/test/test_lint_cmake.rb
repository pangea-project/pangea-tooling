require_relative '../lib/lint/log/cmake'
require_relative 'lib/testcase'

# Test lint cmake
class LintCMakeTest < TestCase
  def data
    path = super
    File.read(path)
  end

  def test_init
    r = Lint::Log::CMake.new.lint(data)
    assert(!r.valid)
    assert(r.informations.empty?)
    assert(r.warnings.empty?)
    assert(r.errors.empty?)
  end

  def test_missing_package
    r = Lint::Log::CMake.new.lint(data)
    assert(r.valid)
    assert_equal(%w(KF5Package), r.warnings)
  end

  def test_optional
    r = Lint::Log::CMake.new.lint(data)
    assert(r.valid)
    assert_equal(%w(Qt5TextToSpeech), r.warnings)
  end

  def test_warning
    r = Lint::Log::CMake.new.lint(data)
    assert(r.valid)
    assert_equal(%w(), r.warnings)
  end

  def test_disabled_feature
    r = Lint::Log::CMake.new.lint(data)
    assert(r.valid)
    assert_equal(['XCB-CURSOR , Required for XCursor support'], r.warnings)
  end

  def test_missing_runtime
    r = Lint::Log::CMake.new.lint(data)
    assert(r.valid)
    assert_equal(['Qt5Multimedia'], r.warnings)
  end
end
