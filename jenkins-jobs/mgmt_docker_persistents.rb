# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerPersistents < JenkinsJob

  def initialize
    super('mgmt_docker_persistents', 'mgmt_docker_persistents.xml.erb')
  end
end
