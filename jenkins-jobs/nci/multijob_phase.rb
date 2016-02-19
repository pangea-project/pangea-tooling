require_relative '../template'

# a phase partial
class MultiJobPhase < Template
  # @!attribute [r] phase_name
  #   @return [String] name of the phase
  attr_reader :phase_name

  # @!attribute [r] phased_jobs
  #   @return [Array<String>] name of the phased jobs
  attr_reader :phased_jobs

  # @param phase_name see {#phase_name}
  # @param phased_jobs see {#phased_jobs}
  def initialize(phase_name:, phased_jobs:)
    super("#{File.basename(__FILE__, '.rb')}.xml.erb")
    @phase_name = phase_name
    @phased_jobs = phased_jobs
  end
end
