require_relative 'job'

class MGMTLXCJob < JenkinsJob
  attr_reader :type
  attr_reader :distribution
  attr_reader :dependees

  def initialize(type:, distribution:, dependees:)
    super("mgmt_lxc_#{distribution}_#{type}", 'mgmt-lxc.xml.erb')
    @type = type
    @distribution = distribution
    @dependees = dependees.collect(&:job_name)
  end
end
