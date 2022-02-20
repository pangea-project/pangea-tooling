# frozen_string_literal: true
require_relative 'dci_project_multi_job'
require_relative '../job'
require_relative '../../lib/dci'

# publisher
class DCIPublisherJob < JenkinsJob
  attr_reader :distribution
  attr_reader :basename
  attr_reader :repo
  attr_reader :component
  attr_reader :name
  attr_reader :architecture
  attr_reader :repo_name

  def initialize(basename, distribution:, series:, component:, name:, architecture:, upload_map:)
    super("#{basename}_pub", 'dci_publisher.xml.erb')
    @basename = basename
    @distribution = distribution
    @series = series
    @component = component
    @name = name
    @architecture = architecture
    @upload_map = upload_map
    raise 'We can do nothing here without an upload_map' unless @upload_map

    @repo = DCI.upload_map_repo(@component)
    @repo_name = DCI.series_release_repo(@series, @repo)
  end

  def aptly_resources
    @repo_name.size > 1 ? 0 : 1
  end
end
