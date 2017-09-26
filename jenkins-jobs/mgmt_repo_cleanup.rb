# frozen_string_literal: true
require_relative 'job'

# Cleans up dockers.
class MGMTRepoCleanupJob < JenkinsJob
  def initialize
    super('mgmt_repo_cleanup', 'mgmt-repo-cleanup.xml.erb')
  end
end
