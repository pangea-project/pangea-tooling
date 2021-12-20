# frozen_string_literal: true
require_relative '../job'

# binary builder
class DCIBinarierJob < JenkinsJob
  attr_reader :basename
  attr_reader :release
  attr_reader :release_type
  attr_reader :series
  attr_reader :dist
  attr_reader :artifact_origin
  attr_reader :downstream_triggers
  attr_reader :architecture

  def initialize(basename, release:, release_type:, series:, dist:, architecture:)
    super("#{basename}_bin", 'dci_binarier.xml.erb')
    @basename = basename
    @release = release
    @release_type = release_type
    @series = series
    @architecture = architecture
    @artifact_origin = "#{basename}_src"
    @dist = dist
    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
  end
end
