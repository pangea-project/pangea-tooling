# frozen_string_literal: true
require_relative '../job'

class DCISnapShotJob < JenkinsJob
  attr_reader :architecture
  attr_reader :type
  attr_reader :snapshot

  def initialize(snapshot:, type:, architecture:)
    @type = type
    @architecture = architecture
    @snapshot = snapshot
    super("snapshot_#{type}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
