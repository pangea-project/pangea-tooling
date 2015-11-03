require 'test/unit'
require_relative '../lib/shebang'

class ExecutableTest < Test::Unit::TestCase
  BINARY_DIRS = %w(
    .
    ci-tooling
    kci
    kci/mgmt
    ci-tooling/kci
    ci-tooling/ci
  )

  SUFFIXES = %w(.py .rb .sh)

  def test_all_binaries_exectuable
    basedir = File.dirname(File.expand_path(File.dirname(__FILE__)))
    not_executable = []
    BINARY_DIRS.each do |dir|
      SUFFIXES.each do |suffix|
        pattern = File.join(basedir, dir, "*#{suffix}")
        Dir.glob(pattern).each do |file|
          next unless File.exist?(file)
          if File.executable?(file)
            sb = Shebang.new(File.open(file).readline)
            assert(sb.valid)
          else
            not_executable << file
          end
        end
      end
    end
    assert(not_executable.empty?, "Missing +x on #{not_executable.join("\n")}")
  end
end
