require_relative 'job'

# Tooling management job.
class MGMTToolingJob < JenkinsJob
  def initialize
    name = 'mgmt_tooling'
    super(name, "#{name}.xml.erb")
  end
end
