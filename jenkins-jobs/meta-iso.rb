require_relative 'job'

class MetaIsoJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution

  def initialize(type:, distribution:)
    super("iso_#{distribution}_#{type}", 'meta-iso.xml.erb')
    @type = type
    @distribution = distribution

    # FIXME: metaiso statically lists all architectures with entires and
    # so forth, this is terrible.
  end
end
