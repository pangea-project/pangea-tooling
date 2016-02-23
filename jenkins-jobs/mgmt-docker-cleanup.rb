require_relative 'job'
require_relative '../ci-tooling/lib/kci'

# Cleans up dockers.
class MGMTDockerCleanupJob < JenkinsJob
  attr_reader :arch

  def initialize(arch:)
    super("mgmt_docker_cleanup_#{arch}", 'mgmt-docker-cleanup.xml.erb')
    @arch = arch
  end
end
