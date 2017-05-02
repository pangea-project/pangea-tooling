require_relative 'job'

# Cleans up dockers.
class MGMTRepoCleanupJob < JenkinsJob
  attr_reader :arch

  def initialize(arch:)
    super("mgmt_repo_cleanup_#{arch}", 'mgmt-repo-cleanup.xml.erb')
    @arch = arch
  end
end
