require_relative '../lib/ci/build_version'
require_relative '../lib/debian/changelog'
require_relative 'lib/testcase'

# Test ci/build_version
class CIBuildVersionTest < TestCase
  REF_TIME = '20150505.0505'

  def setup
    OS.instance_variable_set(:@hash, VERSION_ID: '15.04', ID: 'ubuntu')
    alias_time
  end

  def teardown
    OS.reset
    unalias_time
  end

  def alias_time
    CI::BuildVersion.send(:alias_method, :__time_orig, :time)
    CI::BuildVersion.send(:define_method, :time) { REF_TIME }
    @time_aliased = true
  end

  def unalias_time
    return unless @time_aliased
    CI::BuildVersion.send(:undef_method, :time)
    CI::BuildVersion.send(:alias_method, :time, :__time_orig)
    @time_aliased = false
  end

  def test_all
    c = Changelog.new(data)
    v = CI::BuildVersion.new(c)
    suffix = v.send(:instance_variable_get, :@suffix)

    # Suffix must be comprised of a date and a distribution identifier such
    # that uploads created at the same time for different targets do not
    # conflict one another.
    assert_equal(v.send(:time), REF_TIME)
    parts = suffix.split('+')
    assert_empty(parts[0])
    assert_equal("git#{v.time}", parts[1])
    assert_equal(OS::VERSION_ID, parts[2])
    assert_equal("+git#{v.time}+#{OS::VERSION_ID}", suffix)

    # Check actual versions.
    assert_equal("4:5.2.2#{suffix}", v.base)
    assert_equal("5.2.2#{suffix}", v.tar)
    assert_equal("4:5.2.2#{suffix}-0", v.full)
    assert_equal(v.full, v.to_s)
  end

  def test_bad_os_release
    # os-release doesn't have the var
    OS.reset
    OS.instance_variable_set(:@hash, ID: 'debian')
    c = Changelog.new(data)
    v = CI::BuildVersion.new(c)
    suffix = v.send(:instance_variable_get, :@suffix)
    parts = suffix.split('+')
    assert_equal('9', parts[2])

    OS.instance_variable_set(:@hash, ID: 'ubuntu')
    c = Changelog.new(data)
    assert_raise RuntimeError do
      v = CI::BuildVersion.new(c)
    end

    # Value is nil
    OS.instance_variable_set(:@hash, VERSION_ID: nil, ID: 'ubuntu')
    c = Changelog.new(data)
    assert_raise RuntimeError do
      v = CI::BuildVersion.new(c)
    end

    # Value is empty
    OS.instance_variable_set(:@hash, VERSION_ID: '', ID: 'ubuntu')
    c = Changelog.new(data)
    assert_raise RuntimeError do
      v = CI::BuildVersion.new(c)
    end
  end

  def test_time
    unalias_time
    c = Changelog.new(data)
    v = CI::BuildVersion.new(c)
    # Make sure time is within a one minute delta between what version returns
    # and what datetime.now returns. For the purpose of this excercise the
    # timezone needs to get stripped, so simply run our refernece time through
    # the same string mangling as the actual verson.time
    time_format = v.class::TIME_FORMAT
    time1 = DateTime.strptime(DateTime.now.strftime(time_format), time_format)
    time2 = DateTime.strptime(v.send(:time), time_format)
    datetime_diff = (time2 - time1).to_f
    # One minute rational as float i.e. Rational(1/1440)
    minute_rational_f = 0.0006944444444444445
    assert_in_delta(0.0, datetime_diff.to_f, minute_rational_f,
                    "The time delta between version's time and actual time is" \
                    ' too large.')
  end

  def test_bad_version
    c = Changelog.new(data)
    assert_raise RuntimeError do
      CI::BuildVersion.new(c)
    end
  end
end
