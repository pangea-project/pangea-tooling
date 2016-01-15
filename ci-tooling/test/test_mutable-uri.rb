require_relative 'lib/testcase'
require_relative '../lib/mutable_uri'

# Test mutable-uri
module MutableURI
  class Test < TestCase
    def assert_url(readable_url, writable_url)
      [writable_url, readable_url].each do |url|
        uri = MutableURI.parse(url)
        assert_equal(writable_url, uri.writable.to_s)
        assert_equal(readable_url, uri.readable.to_s)
      end
    end

    def test_debian
      readable_url = 'git://anonscm.debian.org/pkg-kde/yolo'
      writable_url = 'git.debian.org:/git/pkg-kde/yolo'
      assert_url(readable_url, writable_url)
    end

    def test_github
      readable_url = 'https://github.com/blue-systems/pangea-tooling.git'
      writable_url = 'git@github.com:blue-systems/pangea-tooling.git'
      assert_url(readable_url, writable_url)
    end

    def test_kde
      readable_url = 'git://anongit.kde.org/ark.git'
      writable_url = 'git@git.kde.org:ark.git'
      assert_url(readable_url, writable_url)
    end

    def test_unknown
      assert_raise InvalidURIError do
        MutableURI.parse('asdf')
      end
    end
  end
end
