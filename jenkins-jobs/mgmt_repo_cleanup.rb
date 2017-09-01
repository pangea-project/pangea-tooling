require_relative 'job'

# Cleans up dockers.
class MGMTRepoCleanupJob < JenkinsJob
  attr_reader :arch

  def initialize()
    super("mgmt_repo_cleanup", 'mgmt-repo-cleanup.xml.erb')
  end
end
