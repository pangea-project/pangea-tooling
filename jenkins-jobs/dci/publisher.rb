# frozen_string_literal: true
require_relative '../job'
require_relative '../../lib/dci'

# publisher
class DCIPublisherJob < JenkinsJob
  attr_reader :release
  attr_reader :release_type
  attr_reader :series
  attr_reader :distribution
  attr_reader :basename
  attr_reader :repo
  attr_reader :component
  attr_reader :architecture
  attr_reader :artifact_origin

  def initialize(basename, release_type:, release:, series:, architecture:, component:, upload_map:)
    super("#{basename}_pub", 'dci_publisher.xml.erb')
    @release = release
    @release_type = release_type
    @series = series
    @artifact_origin = "#{basename}_bin"
    @basename = basename
    @component = component
    @architecture = architecture
    @distribution = DCI.release_distribution(@release, @series)
    @upload_map = upload_map
    @repo_names = []

    if upload_map
      @repo = DCI.upload_map_repo(@component)
    end
  end

  def repo_names
    @repo_names = ["#{@component}-#{@series}"]
    @repo_names
  end


  def aptly_resources
    @repo_names.size > 1 ? 0 : 1
  end
end
