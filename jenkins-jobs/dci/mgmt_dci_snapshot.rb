# frozen_string_literal: true
require_relative '../job'

class SnapShotJob < JenkinsJob
  attr_reader :type
  attr_reader :architecture
  attr_reader :flavor
  attr_reader :snapshot

  def initialize(snapshot:, type:, flavor:, architecture:)
    @type = type
    @flavor = flavor
    @architecture = architecture
    @snapshot = snapshot
    super("snapshot_#{flavor}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
