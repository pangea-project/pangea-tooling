# frozen_string_literal: true
require_relative '../job'
require_relative '../binarier'

# binary builder
class BinarierJob
  # Monkey patch cores in
  def cores
    JSON.parse(File.read("#{__dir__}/../../data/nci/jobs-to-cores.json")).fetch(job_name, '2')
  end

  def compress?
    %w[qt5webkit qtwebengine
       mgmt_job-updater appstream-generator mgmt_jenkins_archive].any? do |x|
      job_name.include?(x)
    end
  end

  def architecture
    return @architecture unless @architecture == 'i386'
    'amd64'
  end

  def cross_architecture
    @architecture
  end

  def cross_compile?
    @architecture == 'i386'
  end
end
