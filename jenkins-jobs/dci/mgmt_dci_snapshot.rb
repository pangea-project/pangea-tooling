# frozen_string_literal: true
require_relative '../job'

class DCISnapShotJob < JenkinsJob
  attr_reader :architecture
  attr_reader :release_type
  attr_reader :snapshot
  attr_reader :series

  def initialize(snapshot:, series:, release_type:, architecture:)
    @release_type = release_type
    @architecture = architecture
    @snapshot = snapshot
    @series = series
    super("snapshot_#{series}_#{release_type}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
