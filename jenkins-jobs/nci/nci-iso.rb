require_relative '../job'

class NeonIsoJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :metapackage
  attr_reader :imagename
  attr_reader :neonarchive

  def initialize(type:, distribution:, architecture:, metapackage:, imagename:, neonarchive:)
    super("iso_#{imagename}_#{distribution}_#{type}_#{architecture}", 'nci-iso.xml.erb')
    @type = type
    @distribution = distribution
    @architecture = architecture
    @metapackage = metapackage
    @imagename = imagename
    @neonarchive = neonarchive
  end
end
