# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerNodes < JenkinsJob

  def initialize
    super('mgmt_docker_nodes', 'mgmt_docker_nodes.xml.erb')
  end
end
