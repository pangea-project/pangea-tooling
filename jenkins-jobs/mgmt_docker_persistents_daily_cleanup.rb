# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerPersistentsDailyCleanup < JenkinsJob

  def initialize
    super('mgmt_docker_persistents_daily_cleanup', 'mgmt_docker_persistents_daily_cleanup.xml.erb')
  end
end
