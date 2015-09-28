require_relative 'job'

# Tooling management job.
class MGMTToolingJob < JenkinsJob
  attr_reader :downstreams

  def initialize(downstreams:)
    name = 'mgmt_tooling'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
  end
end
