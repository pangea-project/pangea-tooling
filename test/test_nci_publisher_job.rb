require 'test/unit'

require 'webmock'
require 'webmock/test_unit'

require_relative '../jenkins-jobs/nci/publisher'

require 'mocha/test_unit'

class NeonPublisherJobTest < Test::Unit::TestCase
  def test_frameworks_push_to_stable
    JenkinsJob.flavor_dir = "../jenkins-jobs/nci/"
    Template.flavor_dir = "../jenkins-jobs/nci/"
    job = NeonPublisherJob.new('xenial_unstable_kde_attica',
                               type: 'unstable',
                               distribution: 'xenial',
                               dependees: nil,
                               component: 'kde',
                               upload_map: nil,
                               architectures: 'amd64',
                               kdecomponent: 'frameworks')
    assert_equal(job.repo_names, ["unstable_xenial", "stable_xenial"])
  end
end
