# frozen_string_literal: true
require_relative '../job'

# publisher
class DCIPublisherJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :artifact_origin
  attr_reader :downstream_triggers
  attr_reader :basename
  attr_reader :repo
  attr_reader :component
  attr_reader :architecture

  def initialize(basename, type:, distribution:,
                 component:, upload_map:, architecture:)
    super("#{basename}_#{architecture}_pub", 'dci_publisher.xml.erb')
    @type = type
    @distribution = distribution
    @artifact_origin = "#{basename}_#{architecture}_bin"
    @downstream_triggers = []
    @basename = basename
    @component = component
    @architecture = architecture

    if upload_map
      @repo = upload_map[component]
      @repo ||= upload_map['default']
    end
  end

  def append(job)
    @downstream_triggers << job
  end
end
