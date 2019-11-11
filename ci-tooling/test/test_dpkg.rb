require_relative '../lib/dpkg'
require_relative 'lib/assert_backtick'
require_relative 'lib/testcase'

# Test DPKG
class DPKGTest < TestCase
  prepend AssertBacktick

  def test_architectures
    assert_backtick('dpkg-architecture -qDEB_BUILD_ARCH') do
      DPKG::BUILD_ARCH
    end

    assert_backtick('dpkg-architecture -qDEB_BUBU') do
      DPKG::BUBU
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
