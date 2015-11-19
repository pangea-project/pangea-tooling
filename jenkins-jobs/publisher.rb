require_relative 'job'

# publisher
class PublisherJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :artifact_origin
  attr_reader :dependees
  attr_reader :downstream_triggers
  attr_reader :basename
  attr_reader :repo

  def initialize(basename, type:, distribution:, dependees:, component:)
    super("#{basename}_pub", 'publisher.xml.erb')
    @type = type
    @distribution = distribution
    @artifact_origin = "#{basename}_bin"
    @dependees = dependees
    @downstream_triggers = []
    @basename = basename

    if @@upload_target_map
      @repo = @@upload_target_map[component]
      # FIXME: Default to the plasma repo for DCI
      @repo ||= 'plasma'
    end
  end

  def self.upload_target_map=(upload_map)
    @@upload_target_map = upload_map
  end

  def append(job)
    @downstream_triggers << job
  end
end
