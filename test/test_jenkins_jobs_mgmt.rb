require_relative '../jenkins-jobs/mgmt-docker'
require_relative '../ci-tooling/test/lib/testcase'

class MGMTDockerTest < TestCase
  def test_render
    r = MGMTDockerJob.new(type: 'unstable', distribution: 'vivid', dependees: [])
    assert_equal(File.read("#{@datadir}/test_render.xml"), r.render_template)
  end
end
