# frozen_string_literal: true
require_relative '../job'

class DCISnapShotJob < JenkinsJob
  attr_reader :architecture
  attr_reader :release_type
  attr_reader :snapshot
  attr_reader :series

  def initialize(snapshot:, series:, release_type:, arm_board:, architecture:)
    @release_type = release_type
    @architecture = architecture
    @snapshot = snapshot
    @series = series
    @arm_board = arm_board
    if arm_board
      super("snapshot_#{series}_#{release_type}_#{arm_board}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
    else
      super("snapshot_#{series}_#{release_type}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
