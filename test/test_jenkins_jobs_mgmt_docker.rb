require_relative '../ci-tooling/test/lib/testcase'
require_relative '../jenkins-jobs/mgmt_docker'

class MGMTDockerTest < TestCase
  def test_render
    r = MGMTDockerJob.new(dependees: [])
    puts r.render_template
    assert_equal(File.read("#{@datadir}/test_render.xml"), r.render_template)
  end
end
