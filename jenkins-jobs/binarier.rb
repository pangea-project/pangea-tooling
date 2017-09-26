# frozen_string_literal: true
require_relative 'job'

# binary builder
class BinarierJob < JenkinsJob
  attr_reader :basename
  attr_reader :type
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :artifact_origin
  attr_reader :downstream_triggers

  def initialize(basename, type:, distribution:, architecture:)
    super("#{basename}_bin_#{architecture}", 'binarier.xml.erb')
    @basename = basename
    @type = type
    @distribution = distribution
    @architecture = architecture
    @artifact_origin = "#{basename}_src"
    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
  end
end
