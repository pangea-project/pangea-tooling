require_relative 'job'

# Tooling management job.
class MGMTToolingTestJob < JenkinsJob
  attr_reader :downstreams

  def initialize(downstreams:)
    name = 'mgmt_tooling_test'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
  end
end
