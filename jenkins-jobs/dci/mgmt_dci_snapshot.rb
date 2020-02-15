# frozen_string_literal: true
require_relative '../job'

class SnapShotJob < JenkinsJob
  attr_reader :architecture
  attr_reader :flavor
  attr_reader :snapshot

  def initialize(snapshot:, flavor:, architecture:)
    @flavor = flavor
    @architecture = architecture
    @snapshot = snapshot
    super("snapshot_#{flavor}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
