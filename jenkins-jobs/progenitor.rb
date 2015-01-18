require_relative 'job'

# Progenitor is the super super super job triggering everything.
class MgmtProgenitorJob < JenkinsJob
  attr_reader :daily_trigger
  attr_reader :downstream_triggers

  def initialize(downstream_jobs:)
    super('mgmt_progenitor', 'mgmt-progenitor.xml.erb')
    @daily_trigger = '0 0 * * *'
    @downstream_triggers = downstream_jobs.collect(&:job_name)
  end
end
