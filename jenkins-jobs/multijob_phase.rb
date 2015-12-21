require_relative 'job'

# a phase partial
# FIXME: this really should be refactored. JenkinsJob is not an appropriate base
#   as this is not an actual job on its own. it is a job partial that simply
#   relies on the xml templating tech we have
class MultiJobPhase < JenkinsJob
  # @!attribute [r] phase_name
  #   @return [String] name of the phase
  attr_reader :phase_name

  # @!attribute [r] phased_jobs
  #   @return [Array<String>] name of the phased jobs
  attr_reader :phased_jobs

  # @param phase_name see {#phase_name}
  # @param phased_jobs see {#phased_jobs}
  def initialize(phase_name:, phased_jobs:)
    super('random-phase', "#{File.basename(__FILE__, '.rb')}.xml.erb")
    @phase_name = phase_name
    @phased_jobs = phased_jobs
  end
end
