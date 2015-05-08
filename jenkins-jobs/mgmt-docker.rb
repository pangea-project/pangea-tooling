require_relative 'job'
require_relative '../ci-tooling/lib/kci'

class MGMTDockerJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :dependees

  def initialize(type:, distribution:, dependees:)
    super("mgmt_docker_#{distribution}_#{type}", 'mgmt-docker.xml.erb')
    @type = type
    @distribution = distribution
    @version = KCI.series[distribution]
    @dependees = dependees.collect(&:job_name)
  end
end
