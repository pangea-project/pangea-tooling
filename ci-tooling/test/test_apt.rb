# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../lib/apt'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test Apt
class AptTest < TestCase
  def setup
    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def default_args(cmd = 'apt-get')
    [cmd] + %w(-y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true -q)
  end

  def assert_system(*args, &_block)
    Object.any_instance.expects(:system).never
    if args[0].is_a?(Array)
      # Flatten first level. Since we catch *args we get an array with an array
      # which contains the arrays of arguments, by removing the first array we
      # get an array of argument-arrays.
      # COMPAT: we only do this conditionally since the original assert_system
      # was super flexible WRT input types.
      args = args.flatten(1) if args[0][0].is_a?(Array)
      args.each do |arg_array|
        Object.any_instance.expects(:system).with(*arg_array).returns(true)
      end
    else
      Object.any_instance.expects(:system).with(*args).returns(true)
    end
    yield
  ensure
    Object.any_instance.unstub(:system)
  end

  def assert_system_default(args, &block)
    assert_system(*(default_args + args), &block)
  end

  def assert_system_default_get(args, &block)
    assert_system(*(default_args('apt-get') + args), &block)
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

  def test_apt_key_add_invalid_file
    stub_request(:get, 'http://abc/xx.pub').to_return(status: 504)
    assert_raise OpenURI::HTTPError do
      assert_false(Apt::Key.add('http://abc/xx.pub'))
    end
  end

  def test_apt_key_add_keyid
    assert_system('apt-key', 'adv', '--keyserver', 'keyserver.ubuntu.com', '--recv', '0x123456abc') do
      Apt::Key.add('0x123456abc')
    end
  end

  def test_apt_key_add_rel_file
    File.write('abc', 'keyly')
    # Expect IO.popen() {}
    popen_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(popen_catcher)

    assert Apt::Key.add('abc')
    assert_equal("keyly\n", popen_catcher.string)
  end

  def test_apt_key_add_absolute_file
    File.write('abc', 'keyly')
    path = File.absolute_path('abc')
    # Expect IO.popen() {}
    popen_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(popen_catcher)

    assert Apt::Key.add(path)
    assert_equal("keyly\n", popen_catcher.string)
  end

  def test_apt_key_add_url
    url = 'http://kittens.com/key'
    # Expect open()
    data_output = StringIO.new('keyly')
    Object.any_instance.expects(:open)
          .with(url)
          .returns(data_output)
    # Expect IO.popen() {}
    popen_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(popen_catcher)

    assert Apt::Key.add(url)
    assert_equal("keyly\n", popen_catcher.string)
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

  # Test that the deep nesting bullshit behind Repository.add with implicit
  # crap garbage caching actually yields correct return values and is
  # retriable on error.
  def test_fucking_shit_fuck_shit
    Object.any_instance.expects(:system).never

    add_call_chain = proc do |sequence, returns|
      # sequence is a sequence
      # returns is an array of nil/false/true values
      #   first = update
      #   second = install
      #   third = add
      # a nil returns means this call must not occur (can only be 1st & 2nd)
      apt = ['apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', '-q']

      unless (ret = returns.shift).nil?
        Object
          .any_instance
          .expects(:system)
          .in_sequence(sequence)
          .with(*apt, 'update')
          .returns(ret)
      end

      unless (ret = returns.shift).nil?
        Object
          .any_instance
          .expects(:system)
          .in_sequence(sequence)
          .with(*apt, 'install', 'software-properties-common')
          .returns(ret)
      end

      Object
        .any_instance
        .expects(:system)
        .in_sequence(sequence)
        .with('add-apt-repository', '-y', 'kittenshit')
        .returns(returns.shift)
    end

    seq = sequence('apt-add-repo')

    # Enable automatic update. We want to test that we can retry the update
    # if it fails.
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, nil)

    # update failed, install failed, invocation failed
    add_call_chain.call(seq, [false, false, false])
    assert_false(Apt::Repository.add('kittenshit'))
    # update worked, install failed, invocation failed
    add_call_chain.call(seq, [true, false, false])
    assert_false(Apt::Repository.add('kittenshit'))
    # update noop, install worked, invocation failed
    add_call_chain.call(seq, [nil, true, false])
    assert_false(Apt::Repository.add('kittenshit'))
    # update noop, install noop, invocation worked
    add_call_chain.call(seq, [nil, nil, true])
    assert(Apt::Repository.add('kittenshit'))
  end

  def test_cache_exist
    # Check if a package exists.

    # Cache is different in that in includes abstrapt instead of calling it,
    # this is because it actually overrides behavior. It also means we need
    # to disable the auto-update for cache as the setting from Abstrapt
    # doesn't carry over (set via setup).
    Apt::Cache.send(:instance_variable_set, :@last_update, Time.now)
    # Auto-update goes into abstrapt
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    # This is our stuff
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:system)
      .with('apt-cache', '-q', 'show', 'abc', {[:out, :err] => '/dev/null'})
      .returns(true)
    Apt::Cache.expects(:system)
      .with('apt-cache', '-q', 'show', 'cba', {[:out, :err] => '/dev/null'})
      .returns(false)
    assert_true(Apt::Cache.exist?('abc'))
    assert_false(Apt::Cache.exist?('cba'))
  end

  def test_apt_cache_disable_update
    Apt::Cache.reset # make sure we can auto-update
    # Auto-update goes into abstrapt
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    # This is our stuff
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never

    # We expect no update call!

    Apt::Cache
      .expects(:system)
      .with('apt-cache', '-q', 'show', 'abc', {[:out, :err] => '/dev/null'})
      .returns(true)

    ret = Apt::Cache.disable_auto_update { Apt::Cache.exist?('abc'); '123' }
    assert_equal('123', ret)
  end

  def test_key_fingerprint
    # Make sure we get no URI exceptions etc. when adding a fingerprint with
    # spaces, and that it actually calls the correct command.

    Apt::Key.expects(:system).never
    Apt::Key.expects(:`).never

    Apt::Key
      .expects(:system)
      .with('apt-key', 'adv', '--keyserver', 'keyserver.ubuntu.com', '--recv',
            '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D')

    Apt::Key.add('444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D')
  end

  def test_mark_state
    TTY::Command
      .any_instance
      .stubs(:run)
      .with { |*args| args.join.include?('foobar-doesnt-exist') }
      .returns(['', ''])
    TTY::Command
      .any_instance
      .stubs(:run)
      .with { |*args| args.join.include?('zsh-common') }
      .returns(["zsh-common\n", ''])

    # Disabled see code for why.
    # assert_raise { Apt::Mark.state('foobar-doesnt-exist') }
    assert_equal(Apt::Mark::AUTO, Apt::Mark.state('zsh-common'))
  end

  def test_mark_mark
    TTY::Command
      .any_instance
      .stubs(:run).once
      .with do |*args|
        args = args.join
        args.include?('hold') && args.include?('zsh-common')
      end
      .returns(nil)

    Apt::Mark.mark('zsh-common', Apt::Mark::HOLD)
  end

  def test_mark_tmpmark
    pkg = 'zsh-common'
    seq = sequence('cmd_sequence')

    # This is stubbing on a TTY level as we'll want to assert that the block
    # behaves according to expectation, not that the invidiual methods on
    # a higher level are called.
    # NB: this is fairly fragile and might need to be replaced with a more
    #   general purpose mock of apt-mark interception.

    # Initial state query
    TTY::Command
      .any_instance.expects(:run).with(Apt::Mark::BINARY, 'showauto', pkg)
      .returns([pkg, ''])
      .in_sequence(seq)
    # State switch
    TTY::Command
      .any_instance.expects(:run).with(Apt::Mark::BINARY, 'manual', pkg)
      .returns(nil)
      .in_sequence(seq)
    # Test assertion no on auto, yes on manual. This part of the sequence is
    # caused by our assert()
    TTY::Command
      .any_instance.expects(:run).with(Apt::Mark::BINARY, 'showauto', pkg)
      .returns(['', ''])
      .in_sequence(seq)
    TTY::Command
      .any_instance.expects(:run).with(Apt::Mark::BINARY, 'showmanual', pkg)
      .returns([pkg, ''])
      .in_sequence(seq)
    # Block undoes the state to the original state (auto)
    TTY::Command
      .any_instance.expects(:run).with(Apt::Mark::BINARY, 'auto', pkg)
      .returns(nil)
      .in_sequence(seq)

    Apt::Mark.tmpmark(pkg, Apt::Mark::MANUAL) do
      assert_equal(Apt::Mark::MANUAL, Apt::Mark.state(pkg))
    end
  end
end
