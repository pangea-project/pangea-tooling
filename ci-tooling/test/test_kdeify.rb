require_relative '../lib/kdeify'
require_relative '../lib/debian/control'
require_relative 'lib/testcase'

class KDEIfyTest < TestCase
  required_binaries %w(quilt filterdiff)

  def setup
    FileUtils.cp_r("#{data}/.", Dir.pwd)
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
    assert(control.binaries.map {|x| x['Package']}.include? 'firefox-plasma')
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
    assert(control.binaries.map {|x| x['Package']}.include? 'thunderbird-plasma')
  end
end
