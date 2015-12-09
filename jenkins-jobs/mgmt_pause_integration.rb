require_relative 'job'

# Pause integration management job.
class MGMTPauseIntegrationJob < JenkinsJob
  attr_reader :downstreams

  def initialize(downstreams:)
    name = File.basename(__FILE__, '.rb')
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
  end
end
