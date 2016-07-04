require 'vcr'
require 'webmock/test_unit'

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

    def test_fetch_escaped_orig
      VCR.use_cassette(__method__) do
        f = URLTarFetcher.new('http://http.debian.net/debian/pool/main/libd/libdbusmenu-qt/libdbusmenu-qt_0.9.3%2B15.10.20150604.orig.tar.gz')
        t = f.fetch(Dir.pwd)
        file = File.basename(t.origify.path)
        assert_equal('libdbusmenu-qt_0.9.3+15.10.20150604.orig.tar.gz', file)
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

      Test.http_serve(data('http'), port: SERVER_PORT) do
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

    # test code to mange the watch file to look at alternative server
    # currently only works on stable/plasma
    def test_mangle_watch
      require_binaries(%w(uscan))
      Dir.mkdir('debian')
      FileUtils.cp(data('watch'), 'debian/')
      WatchTarFetcher.new('debian/watch', true)
      File.open('debian/watch').each do |line|
        line.chomp!
        assert_equal('http://download.kde.org.uk/stable/plasma/([\d.]+)/kgamma5-([\d.]+).tar.xz', line)
      end
    end

    description 'when destdir does not exist uscan shits its pants'
    def test_watch_create_destdir
      require_binaries(%w(uscan))

      # Create an old file. The fetcher is meant to remove this.
      File.write('dragon_15.08.1.orig.tar.xz', '')

      Test.http_serve(data('http'), port: SERVER_PORT) do
        f = WatchTarFetcher.new(data('debian/watch'))
        f.fetch('source')

        assert_path_exist('source/dragon_15.08.1.orig.tar.xz')
      end
    end

    def test_url_fetch_twice
      VCR.turned_off do
        stub_request(:get, 'http://troll/dragon-15.08.1.tar.xz')
          .to_return(body: File.read(data('http/dragon-15.08.1.tar.xz')))

        f = URLTarFetcher.new('http://troll/dragon-15.08.1.tar.xz')
        t = f.fetch(Dir.pwd)
        assert_false(t.orig?, "File orig but was not meant to #{t.inspect}")

        # And again this actually should not do a request.
        f = URLTarFetcher.new('http://troll/dragon-15.08.1.tar.xz')
        t = f.fetch(Dir.pwd)
        assert_false(t.orig?, "File orig but was not meant to #{t.inspect}")

        assert_requested(:get, 'http://troll/dragon-15.08.1.tar.xz', times: 1)
      end
    end
  end
end
