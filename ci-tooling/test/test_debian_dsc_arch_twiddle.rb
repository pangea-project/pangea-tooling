require 'fileutils'

require_relative '../lib/debian/dsc_arch_twiddle'
require_relative 'lib/testcase'

# Test debian/source/format
module Debian
  class DSCArchTwiddleTest < TestCase
    def teardown
      ENV.delete('ENABLED_EXTRA_ARCHITECTURES')
    end

    def tmpdirdata
      File.join(Dir.pwd, File.basename(data))
    end

    # Note: data is a method that resolves the fixture path from the
    #   calling test_ method name. So we can not set up from setup.
    def copy_data
      FileUtils.cp_r(Dir.glob(data), Dir.pwd)
    end

    def assert_twiddles(expected_str, env: [])
      ENV.delete('ENABLED_EXTRA_ARCHITECTURES')
      ENV['ENABLED_EXTRA_ARCHITECTURES'] = env.join(' ') unless env.empty?
      copy_data
      DSCArch.twiddle!(tmpdirdata)
      lines = File.read("#{tmpdirdata}/my.dsc").lines
      assert_equal(expected_str, lines[3])
    end

    def test_too_many
      copy_data
      assert_raise Debian::DSCArch::CountError do
        DSCArch.twiddle!(tmpdirdata)
      end
    end

    def test_any
      assert_twiddles("Architecture: amd64 i386\n")
      assert_twiddles("Architecture: amd64 i386 armhf\n", env: %w(armhf))
    end

    def test_linux_any
      assert_twiddles("Architecture: amd64 i386\n")
      assert_twiddles("Architecture: amd64 i386 armhf\n", env: %w(armhf))
    end

    def test_any_all
      assert_twiddles("Architecture: amd64 i386 all\n")
      assert_twiddles("Architecture: amd64 i386 armhf all\n", env: %w(armhf))
    end

    def test_i386_amd64
      # Note: order is as in input (which is non-alpahabetical)
      assert_twiddles("Architecture: i386 amd64\n")
      assert_twiddles("Architecture: i386 amd64\n", env: %w(armhf))
    end

    def test_i386_amd64_all
      # Note: order is as in input (which is non-alpahabetical).
      assert_twiddles("Architecture: i386 amd64 all\n")
      assert_twiddles("Architecture: i386 amd64 all\n", env: %w(armhf))
    end

    def test_randomextraarch_all
      assert_twiddles("Architecture: all\n")
      # Not in KCI data, won't be allowed even if in ENV...
      assert_twiddles("Architecture: all\n", env: %w(randomextraarch))
    end

    def test_randomextraarch
      assert_raise DSCArch::EmptyError do
        copy_data
        DSCArch.twiddle!(tmpdirdata)
      end
    end

    def test_no_arch
      assert_raise DSCArch::EmptyError do
        copy_data
        DSCArch.twiddle!(tmpdirdata)
      end
    end

    def test_multiline
      # Line after Architecture starts with a space, indicating a folded field
      # but we can't handle folding right now, so we expect a fail.
      assert_raise DSCArch::MultilineError do
        copy_data
        DSCArch.twiddle!(tmpdirdata)
      end
    end
  end
end
