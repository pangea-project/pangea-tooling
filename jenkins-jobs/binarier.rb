require_relative 'job'

# binary builder
class BinarierJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :artifact_origin
  attr_reader :downstream_triggers

  def initialize(basename, type:, distribution:)
    super("#{basename}_bin", 'binarier.xml.erb')
    @type = type
    @distribution = distribution
    @artifact_origin = "#{basename}_src"
    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
  end
end
