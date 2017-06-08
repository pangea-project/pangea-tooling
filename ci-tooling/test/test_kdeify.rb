require_relative '../lib/kdeify'
require_relative '../lib/debian/control'
require_relative 'lib/testcase'

class KDEIfyTest < TestCase
  required_binaries %w(quilt filterdiff)

  def setup
    FileUtils.cp_r("#{data}/.", Dir.pwd)
    ENV['DIST'] = '1706'
    OS.reset
    OS.instance_variable_set(:@hash, VERSION_ID: '15.04')
  end

  def teardown
    OS.reset
  end

  def test_firefox
    KDEIfy.firefox!
    assert(File.exist? 'packaging/debian/patches/firefox-kde.patch')
    assert(File.exist? 'packaging/debian/patches/mozilla-kde.patch')
    # assert(File.exist? 'packaging/debian/patches/unity-menubar.patch')

    patches = File.read('packaging/debian/patches/series')
    assert(patches.include? 'firefox-kde.patch')
    assert(patches.include? 'mozilla-kde.patch')
    # assert(patches.include? 'unity-menubar.patch')

    control = Debian::Control.new('packaging/')
    control.parse!
    #assert(control.binaries.map {|x| x['Package']}.include? 'firefox-plasma')

    Dir.chdir('packaging') do
      c = Changelog.new
      assert_equal('1:46.0+build5-0ubuntu0.14.04.2+15.04+1706', c.version)
    end
  end

  def test_thunderbird
    KDEIfy.thunderbird!
    assert(File.exist? 'packaging/debian/patches/firefox-kde.patch')
    assert(File.exist? 'packaging/debian/patches/mozilla-kde.patch')
    # assert(File.exist? 'packaging/debian/patches/unity-menubar.patch')

    patches = File.read('packaging/debian/patches/series')
    assert(patches.include? 'firefox-kde.patch')
    assert(patches.include? 'mozilla-kde.patch')
    # assert(patches.include? 'unity-menubar.patch')

    control = Debian::Control.new('packaging/')
    control.parse!
    #assert(control.binaries.map {|x| x['Package']}.include? 'thunderbird-plasma')
    Dir.chdir('packaging') do
      c = Changelog.new
      assert_equal('2:38.7.2+build1-0ubuntu0.14.04.1+15.04+1706', c.version)
    end
  end
end
