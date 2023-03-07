# frozen_string_literal: true
require_relative '../job'

# Progenitor is the super super super job triggering everything.
class I386InstallCheckJob < JenkinsJob
  attr_reader :distribution
  attr_reader :type
  attr_reader :dependees

  def initialize(distribution:, type:, dependees:)
    super("mgmt_i386_install_check_#{distribution}_#{type}",
          'i386-install-check.xml.erb')
    @distribution = distribution
    @type = type
    @dependees = dependees.collect(&:job_name)
  end
end
