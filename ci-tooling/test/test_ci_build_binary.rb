require_relative '../lib/ci/build_binary'
require_relative '../lib/debian/changes'
require_relative 'lib/testcase'

# Test ci/build_binary
module CI
  class BuildBinaryTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg dh)

    def test_build_package
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)

      builder = PackageBuilder.new
      builder.build_package

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('*.deb'))
      assert_path_exist('hello_2.10-1_amd64.changes')
      changes = Debian::Changes.new('hello_2.10-1_amd64.changes')
      changes.parse!
      assert_equal(['hello_2.10-1_amd64.deb'],
                   changes.fields['files'].map(&:name))
    end
  end
end
