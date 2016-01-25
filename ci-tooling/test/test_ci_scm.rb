require_relative '../lib/ci/upstream_scm'
require_relative 'lib/testcase'

# Test ci/upstream_scm
module CI
  class SCMTest < TestCase
    def test_init
      type = 'git'
      url = 'git.debian.org:/git/pkg-kde/yolo'
      branch = 'master'
      scm = SCM.new(type, url, branch)
      assert_equal(type, scm.type)
      assert_equal(url, scm.url)
      assert_equal(branch, scm.branch)
    end

    def test_tarball
      SCM.new('tarball', 'http://www.example.com/foo.tar.xz')
    end

    def test_cleanup_uri
      assert_equal('/a/b', SCM.cleanup_uri('/a//b/'))
      assert_equal('http://a.com/b', SCM.cleanup_uri('http://a.com//b//'))
      assert_equal('//host/b', SCM.cleanup_uri('//host/b/'))
      # This parses as opaque component with lp as scheme. We only clean path
      # so we cannot clean this without assuming that opaque is in fact
      # equal to path (Which it is not...)
      assert_equal('lp:kitten', SCM.cleanup_uri('lp:kitten'))
      assert_equal('lp:kitten///', SCM.cleanup_uri('lp:kitten///'))
    end
  end
end
