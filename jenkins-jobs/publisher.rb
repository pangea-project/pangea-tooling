require_relative 'job'

# publisher
class PublisherJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :artifact_origin
  attr_reader :dependees
  attr_reader :downstream_triggers
  attr_reader :basename

  def initialize(basename, type:, distribution:, dependees:)
    super("#{basename}_pub", 'publisher.xml.erb')
    @type = type
    @distribution = distribution
    @artifact_origin = "#{basename}_bin"
    @dependees = dependees
    @downstream_triggers = []
    @basename = basename
  end

  def append(job)
    @downstream_triggers << job
  end
end
