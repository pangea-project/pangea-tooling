require_relative '../jenkins-jobs/mgmt-docker-cleanup.rb'
require_relative '../ci-tooling/test/lib/testcase'

class JenkinsJobsMGMTDockerCleanupTest < TestCase
  def test_render
    r = MGMTDockerCleanupJob.new(arch: 'arch')
    assert_equal(File.read("#{@datadir}/test_render.xml"), r.render_template)
  end
end
