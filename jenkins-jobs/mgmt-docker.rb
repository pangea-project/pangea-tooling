require_relative 'job'
require_relative '../ci-tooling/lib/kci'

class MGMTDockerJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :dependees
  attr_reader :version
  attr_reader :arch

  def initialize(type:, distribution:, dependees:, arch: nil)
    name = "mgmt_docker_#{distribution}_#{type}" unless arch
    name = "mgmt_docker_#{distribution}_#{type}_#{arch}" if arch
    super(name, 'mgmt-docker.xml.erb')
    @type = type
    @distribution = distribution
    @version = KCI.series[distribution]
    @dependees = dependees.collect(&:job_name)
    @arch = arch
  end
end
