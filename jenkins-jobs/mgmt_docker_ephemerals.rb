# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerEphemerals < JenkinsJob

  def initialize
    super('mgmt_docker_ephemerals', 'mgmt_docker_ephemerals.xml.erb')
  end
end
