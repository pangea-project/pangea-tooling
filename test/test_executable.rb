require 'test/unit'
require_relative '../lib/shebang'

class ExecutableTest < Test::Unit::TestCase
  BINARY_DIRS = %w[
    .
    bin
    ci-tooling
    ci-tooling/bin
    ci-tooling/ci
    ci-tooling/dci
    ci-tooling/kci
    ci-tooling/mci
    ci-tooling/nci
    dci
    mci
    nci
    aci
    mgmt
  ].freeze

  SUFFIXES = %w[.py .rb .sh].freeze

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
            assert(sb.valid, "Invalid shebang #{file}")
          else
            not_executable << file
          end
        end
      end
    end
    # Use a trailing space to make sure we can copy crap without a terminal
    # fullstop inserted by test-unit.
    assert(not_executable.empty?, "Missing +x on #{not_executable.join("\n")} ")
  end
end
