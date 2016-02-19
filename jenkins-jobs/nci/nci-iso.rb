require_relative '../job'

class NeonIsoJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :metapackage
  attr_reader :imagename

  def initialize(type:, distribution:, architecture:, metapackage:, imagename:)
    super("iso_#{imagename}_#{distribution}_#{type}_#{architecture}", 'nci-iso.xml.erb')
    @type = type
    @distribution = distribution
    @architecture = architecture
    @metapackage = metapackage
    @imagename = imagename
  end
end
