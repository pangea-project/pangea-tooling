require_relative 'job'

class MGMTDockerJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :dependees

  def initialize(type:, distribution:, dependees:)
    super("mgmt_docker_#{distribution}_#{type}", 'mgmt-docker.xml.erb')
    @type = type
    @distribution = distribution
    @dependees = dependees.collect(&:job_name)
  end
end
