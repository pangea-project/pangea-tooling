require_relative '../lib/ci/upstream_scm'
require_relative 'lib/testcase'

# Test ci/upstream_scm
class UpstreamSCMTest < TestCase
  def test_defaults
    scm = UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
  end
end
