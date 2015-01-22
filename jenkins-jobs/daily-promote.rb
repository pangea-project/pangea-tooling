require_relative 'job'

# Progenitor is the super super super job triggering everything.
class DailyPromoteJob < JenkinsJob
  attr_reader :distribution
  attr_reader :type

  def initialize(distribution:, type:)
    super("mgmt_daily_promotion_#{distribution}_#{type}",
          'daily-promote.xml.erb')
    @distribution = distribution
    @type = type
  end
end
