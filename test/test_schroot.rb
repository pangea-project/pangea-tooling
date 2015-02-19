require 'fileutils'
require 'test/unit'
require 'tmpdir'

require_relative '../schroot-scripts/setup-chroot-imager'

class SchrootTest < Test::Unit::TestCase
  def const_reset_dir(klass, symbol, string)
    klass.send(:remove_const, symbol)
    klass.const_set(symbol, string)
    FileUtils.mkpath(string)
  end

  def setup
    @datadir = "#{File.expand_path(File.dirname(__FILE__))}/data/#{File.basename(__FILE__, '.rb')}"

    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
    chrootdir = "#{@tmpdir}/chroot"
    const_reset_dir(Schroot, :CHROOT_DIR, chrootdir)
    etcdir = "#{@tmpdir}/etc"
    const_reset_dir(Schroot, :CONF_DIR, etcdir)
    const_reset_dir(Schroot, :CONF_CHROOT_DIR, "#{etcdir}/chroot.d")
    jenkinsdir = "#{@tmpdir}/jenkins"
    const_reset_dir(Schroot, :JENKINS_DIR, jenkinsdir)
    const_reset_dir(Schroot, :JENKINS_TOOLING, "#{jenkinsdir}/tooling/imager")
    # noop debootstrap and run_setup; They really properly require root.
    Schroot.send(:define_method, :debootstrap, proc {})
    Schroot.send(:define_method, :run_setup, proc {})
  end

  def data(path)
    index = 0
    caller = ''
    until caller.start_with?('test_')
      caller = caller_locations(index, 1)[0].label
      index += 1
    end
    "#{@datadir}/#{caller}/#{path}"
  end

  def teardown
    Dir.chdir('/tmp')
    FileUtils.rm_rf(@tmpdir)
  end

  def test_create
    schroot = Schroot.new(stability: 'unstable', series: 'utopic',
                          arch: 'amd64')
    schroot.create

    # Setup script must be +x
    assert(File.exist?("#{schroot.chroot_dir}/root/__setup.sh"))
    assert(File.executable?("#{schroot.chroot_dir}/root/__setup.sh"))

    reffiles = Dir.chdir(data('_ref')) { Dir['**/**'] }.sort
    tmpfiles = Dir.chdir('etc') { Dir['**/**'] }.sort

    assert_equal(reffiles, tmpfiles)

  end
end
