require_relative '../lib/apt'
require_relative 'lib/assert_system'
require_relative 'lib/testcase'

# Test Apt
class AptTest < TestCase
  prepend AssertSystem

  def setup
    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def test_repo
    repo = nil
    name = 'ppa:yolo'

    # This will be cached and not repated for static use later.
    assert_system_default(%w(install software-properties-common)) do
      repo = Apt::Repository.new(name)
    end

    cmd = ['add-apt-repository', '-y', 'ppa:yolo']
    assert_system(cmd) { repo.add }
    # Static
    assert_system(cmd) { Apt::Repository.add(name) }

    cmd = ['add-apt-repository', '-y', '-r', 'ppa:yolo']
    assert_system(cmd) { repo.remove }
    # Static
    assert_system(cmd) { Apt::Repository.remove(name) }
  end

  def default_args(cmd = 'apt-get')
    [cmd] + %w(-y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true)
  end

  def assert_system_default(args, &block)
    assert_system(default_args + args, &block)
  end

  def assert_system_default_get(args, &block)
    assert_system(default_args('apt-get') + args, &block)
  end

  def test_apt_install
    assert_system_default(%w(install abc)) do
      Apt.install('abc')
    end

    assert_system_default_get(%w(install abc)) do
      Apt::Get.install('abc')
    end
  end

  def test_apt_install_with_additional_arg
    assert_system_default(%w(--purge install abc)) do
      Apt.install('abc', args: '--purge')
    end
  end

  def test_underscore
    assert_system_default(%w(dist-upgrade)) do
      Apt.dist_upgrade
    end
  end

  def test_apt_install_array
    # Make sure we can pass an array as argument as this is often times more
    # convenient than manually converting it to a *.
    assert_system_default(%w(install abc def)) do
      Apt.install(%w(abc def))
    end
  end

  def assert_add_popen
    class << Open3
      alias_method popen3__, popen3
      def popen3(*args)
        yield
      end
    end
  ensure
    class << Open3
      alias_method popen3, popen3__
    end
  end

  def test_apt_key_add
    assert_system(%w(apt-key add abc)) do
      Apt::Key.add('abc')
    end
  end

  def test_automatic_update
    # Updates
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, nil)
    assert_system([default_args + ['update'],
                   default_args + %w(install abc)]) do
      Apt.install('abc')
    end
    ## Make sure the time stamp difference after the run is <60s and
    ## a subsequent run doesn't update again.
    t = Apt::Abstrapt.send(:instance_variable_get, :@last_update)
    assert(Time.now - t < 60)
    assert_system_default(%w(install def)) do
      Apt.install(%w(def))
    end

    # Doesn't update if recent
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
    assert_system([default_args + %w(install abc)]) do
      Apt.install('abc')
    end

    # Doesn't update if update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, nil)
    assert_system([default_args + ['update']]) do
      Apt.update
    end
  end
end
