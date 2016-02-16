require 'vcr'

require_relative 'lib/serve'
require_relative 'lib/testcase'

require_relative '../lib/ci/tar_fetcher'

module CI
  class TarFetcherTest < TestCase
    SERVER_PORT = '9475'.freeze

    def setup
      VCR.configure do |config|
        config.cassette_library_dir = @datadir
        config.hook_into :webmock
        config.default_cassette_options = {
          match_requests_on: [:method, :uri, :body]
        }
      end
    end

    def test_fetch
      VCR.use_cassette(__method__) do
        f = URLTarFetcher.new('http://people.ubuntu.com/~apachelogger/.static/testu-1.0.tar.xz')
        t = f.fetch(Dir.pwd)
        assert(t.is_a?(Tarball))
        assert_path_exist('testu-1.0.tar.xz')
        assert_false(t.orig?)
        assert_equal('testu_1.0.orig.tar.xz', File.basename(t.origify.path))
      end
    end

    def test_fetch_orig
      VCR.use_cassette(__method__) do
        f = URLTarFetcher.new('http://people.ubuntu.com/~apachelogger/.static/testu_1.0.orig.tar.xz')
        t = f.fetch(Dir.pwd)
        assert(t.orig?)
      end
    end

    # TODO: maybe split
    def test_watch_fetch
      require_binaries(%w(uscan))

      assert_raise RuntimeError do
        WatchTarFetcher.new('/a/b/c')
        # Not a watch
      end
      assert_raise RuntimeError do
        WatchTarFetcher.new('/a/b/watch')
        # Not a debian dir
      end

      Test.http_serve(data('http'), SERVER_PORT) do
        f = WatchTarFetcher.new(data('debian/watch'))
        t = f.fetch(Dir.pwd)

        # assert_path_exist('dragon_15.08.1.orig.tar.xz')
        assert_equal(Tarball, t.class)
        assert_path_exist('dragon_15.08.1.orig.tar.xz')
        assert(t.orig?) # uscan mangles by default, we expect it like that
        assert_equal('dragon_15.08.1.orig.tar.xz',
                     File.basename(t.origify.path))
      end
    end
  end
end
