# frozen_string_literal: true
require_relative '../lib/dpkg'
require_relative 'lib/assert_backtick'
require_relative 'lib/testcase'

# Test DPKG
class DPKGTest < TestCase
  def test_architectures
    TTY::Command
      .any_instance
      .expects(:run)
      .with('dpkg-architecture', '-qDEB_BUILD_ARCH')
      .returns(-> {
        status = mock('arch_status')
        status.stubs(:out).returns("foobar\n")
        status
      }.())

    assert_equal('foobar', DPKG::BUILD_ARCH)
  end

  def test_architectures_fail
    err_status = mock('status')
    err_status.stubs(:out)
    err_status.stubs(:err)
    err_status.stubs(:exit_status)
    TTY::Command
      .any_instance
      .expects(:run)
      .with('dpkg-architecture', '-qDEB_BUBU')
      .raises(TTY::Command::ExitError.new("bubub", err_status))

    assert_equal(nil, DPKG::BUBU)
  end

  def test_listing
    TTY::Command
      .any_instance
      .expects(:run)
      .with('dpkg', '-L', 'abc')
      .returns( -> {
        status = mock('status')
        status.stubs(:out).returns("/.\n/etc\n/usr\n")
        status
      }.())

    assert_equal(
      %w[/. /etc /usr],
      DPKG.list('abc')
    )
  end
end

class DPKGArchitectureTest < TestCase
  def test_is
    arch = DPKG::Architecture.new
    arch.expects(:system)
        .with('dpkg-architecture', '--is', 'amd64')
        .returns(true)
    assert(arch.is('amd64'))
    arch.expects(:system)
        .with('dpkg-architecture', '--is', 'amd64')
        .returns(false)
    refute(arch.is('amd64'))
  end

  def test_is_with_host_arch
    arch = DPKG::Architecture.new(host_arch: 'arm64')
    arch.expects(:system)
        .with('dpkg-architecture', '--host-arch', 'arm64', '--is', 'amd64')
        .returns(false)
    refute(arch.is('amd64'))
  end

  def test_is_with_host_arch_empty
    # empty string should result in no argument getting set
    arch = DPKG::Architecture.new(host_arch: '')
    arch.expects(:system)
        .with('dpkg-architecture', '--is', 'amd64')
        .returns(true)
    assert(arch.is('amd64'))
  end
end
