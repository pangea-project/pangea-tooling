require 'rubygems/package'

require_relative 'lib/testcase'
require_relative '../lib/ci/orig_source_builder'

module CI
  class OrigSourceBuilderTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg dh uscan)

    def setup
      LSB.reset
      LSB.instance_variable_set(:@hash, DISTRIB_CODENAME: 'vivid', DISTRIB_RELEASE: '15.04')
      OS.reset
      OS.instance_variable_set(:@hash, VERSION_ID: '15.04')
      ENV['BUILD_NUMBER'] = '3'
      @tarname = 'dragon_15.08.1.orig.tar.xz'
      @tarfile = "#{Dir.pwd}/#{@tarname}"
      FileUtils.cp_r(Dir.glob("#{data}/."), Dir.pwd)
      FileUtils.cp_r("#{@datadir}/http/dragon-15.08.1.tar.xz", @tarfile)
    end

    def teardown
      LSB.reset
      OS.reset
    end

    def tar_file_list(path)
      files = []
      Gem::Package::TarReader.new(Zlib::GzipReader.open(path)).tap do |reader|
        reader.rewind
        reader.each do |entry|
          files << File.basename(entry.full_name) if entry.file?
        end
        reader.close
      end
      files
    end

    def test_run
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new
      builder.build(tarball)

      # On 14.04 the default was .gz, newer versions may yield .xz
      debian_tar = Dir.glob('build/dragon_15.08.1-0+15.04+build3.debian.tar.*')
      assert_false(debian_tar.empty?, "no tar #{Dir.glob('build/*')}")
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3.dsc')
      assert_path_exist('build/dragon_15.08.1.orig.tar.xz')
      changes = File.read('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_include(changes.split($/), 'Distribution: vivid')
    end

    def test_existing_builddir
      # Now with build dir.
      Dir.mkdir('build')
      assert_nothing_raised do
        OrigSourceBuilder.new
      end
      assert_path_exist('build')
    end

    def test_unreleased_changelog
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new(release: 'unstable')
      builder.build(tarball)

      debian_tar = Dir.glob('build/dragon_15.08.1-0+15.04+build3.debian.tar.*')
      assert_false(debian_tar.empty?, "no tar #{Dir.glob('build/*')}")
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3.dsc')
      assert_path_exist('build/dragon_15.08.1.orig.tar.xz')
      changes = File.read('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_include(changes.split($/), 'Distribution: unstable')
    end

    def test_symbols_strip
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new(strip_symbols: true)
      builder.build(tarball)
      Dir.chdir('build') do
        tar = Dir.glob('*.tar.gz')
        assert_equal(1, tar.size)
        files = tar_file_list(tar[0])
        assert_not_include(files, 'symbols')
        assert_not_include(files, 'dragonplayer.symbols')
        assert_not_include(files, 'dragonplayer.symbols.armhf')
      end
    end
  end
end
