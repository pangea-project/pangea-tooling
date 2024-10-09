# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerPersistentsCleanup < JenkinsJob

  def initialize
    super('mgmt_docker_persistents_cleanup', 'mgmt_docker_persistents_cleanup.xml.erb')
  end
end
