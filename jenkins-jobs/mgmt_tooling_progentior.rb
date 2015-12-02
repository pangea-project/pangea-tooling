require_relative 'job'

# Tooling management job. Deploys archive.tar with tooling onto all slaves.
class MGMTToolingDeployJob < JenkinsJob
  attr_reader :downstreams

  def initialize(downstreams:)
    name = 'mgmt_tooling_deploy'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
  end
end
