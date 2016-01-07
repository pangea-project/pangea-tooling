require_relative 'job'

class NeonIsoJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture

  def initialize(type:, distribution:, architecture:)
    super("iso_#{distribution}_#{type}_#{architecture}", 'nci-iso.xml.erb')
    @type = type
    @distribution = distribution
    @architecture = architecture
  end
end
