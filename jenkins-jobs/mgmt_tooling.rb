require_relative 'job'

# Tooling management job.
class MGMTToolingJob < JenkinsJob
  attr_reader :downstreams
  attr_reader :dependees

  def initialize(downstreams:, dependees:)
    name = 'mgmt_tooling'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
    @dependees = dependees
  end
end
