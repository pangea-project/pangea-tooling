require_relative 'lib/testcase'

require_relative '../lib/ci/orig_source_builder'

module CI
  class OrigSourceBuilderTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg dh uscan)

    def setup
      LSB.reset
      LSB.instance_variable_set(:@hash, DISTRIB_CODENAME: 'vivid', DISTRIB_RELEASE: '15.04')
      ENV['BUILD_NUMBER'] = '3'
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
    end

    def teardown
      LSB.reset
    end

    def test_run
      assert_false(Dir.glob('*').empty?)

      tarball = WatchTarFetcher.new('packaging/debian/watch').fetch(Dir.pwd)

      builder = OrigSourceBuilder.new
      builder.build(tarball)

      # On 14.04 the default was .gz, newer versions may yield .xz
      debian_tar = Dir.glob('build/dragon_15.08.1-0+15.04+build3.debian.tar.*')
      assert_false(debian_tar.empty?)
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

      tarball = WatchTarFetcher.new('packaging/debian/watch').fetch(Dir.pwd)

      builder = OrigSourceBuilder.new(release: 'unstable')
      builder.build(tarball)

      debian_tar = Dir.glob('build/dragon_15.08.1-0+15.04+build3.debian.tar.*')
      assert_false(debian_tar.empty?)
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_path_exist('build/dragon_15.08.1-0+15.04+build3.dsc')
      assert_path_exist('build/dragon_15.08.1.orig.tar.xz')
      changes = File.read('build/dragon_15.08.1-0+15.04+build3_source.changes')
      assert_include(changes.split($/), 'Distribution: unstable')
    end
  end
end
