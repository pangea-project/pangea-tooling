# frozen_string_literal: true
require_relative '../job'

# binary builder
class DCIBinarierJob < JenkinsJob
  attr_reader :basename
  attr_reader :release
  attr_reader :series
  attr_reader :artifact_origin
  attr_reader :downstream_triggers
  attr_reader :architecture

  def initialize(basename, release:, series:, architecture:)
    super("#{basename}_bin", 'dci_binarier.xml.erb')
    @basename = basename
    @release = release
    @series = series
    @architecture = architecture
    @artifact_origin = "#{basename}__src"
    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
  end
end
