# frozen_string_literal: true
require_relative '../job'

# Neon IMGs
class NeonImgJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :metapackage
  attr_reader :imagename
  attr_reader :neonarchive
  attr_reader :cronjob

  def initialize(type:, distribution:, architecture:, metapackage:, imagename:,
                 neonarchive:, cronjob:)
    super("img_#{imagename}_#{distribution}_#{type}_#{architecture}",
          'nci_img.xml.erb')
    @type = type
    @distribution = distribution
    @architecture = architecture
    @metapackage = metapackage
    @imagename = imagename
    @neonarchive = neonarchive
    @cronjob = cronjob
  end
end
