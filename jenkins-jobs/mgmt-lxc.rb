require_relative 'job'

class MGMTLXCJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution

  def initialize(type:, distribution:, architecture:)
    super("mgmt_lxc_#{distribution}_#{type}", 'mgmt-lxc.xml.erb')
    @type = type
    @distribution = distribution
  end
end
