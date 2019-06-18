# frozen_string_literal: true
require_relative '../job'

class SnapShotJob < JenkinsJob
  attr_reader :type
  attr_reader :release
  attr_reader :architecture
  attr_reader :flavor
  attr_reader :snapshot

  def initialize(snapshot:, type:, flavor:, release:, architecture:)
    @type = type
    @flavor = flavor
    @release = release
    @architecture = architecture
    @snapshot = snapshot
    super("snapshot_#{type}_#{flavor}_#{release}_#{snapshot}_#{architecture}", 'mgmt_dci_snapshot.xml.erb')
  end
end
