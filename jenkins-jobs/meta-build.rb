require_relative 'job'

# Meta builder depending on all builds and being able to trigger them.
class MetaBuildJob < JenkinsJob
  attr_reader :downstream_triggers

  def initialize(type:, distribution:, downstream_jobs:)
    super("mgmt_build_#{distribution}_#{type}", 'meta-build.xml.erb')
    @downstream_triggers = downstream_jobs.collect(&:job_name)
  end
end
