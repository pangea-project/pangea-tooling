require_relative 'job'

class NeonIsoJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :meta

  def initialize(type:, distribution:, architecture:, meta:)
    super("iso_#{distribution}_#{type}_#{architecture}", 'nci-iso.xml.erb')
    @type = type
    @distribution = distribution
    @meta = meta
  end
end
