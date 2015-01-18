require 'erb'

require_relative '../ci-tooling/lib/jenkins'

# Base class for Jenkins jobs.
class JenkinsJob
  # FIXME: redundant should be name
  attr_reader :job_name

  attr_reader :template_path

  def initialize(job_name, template_name)
    @job_name = job_name
    file_directory = File.expand_path(File.dirname(__FILE__))
    @template_path = "#{file_directory}/templates/#{template_name}"
    fail "Template #{template_name} not found" unless File.exist?(@template_path)
  end

  # Creates or updates the Jenkins job.
  # @return the job_name
  def update
    xml = render(@template_path)
    begin
      print "Updating #{job_name}\n"
      Jenkins.job.create_or_update(job_name, xml)
    rescue => e
      puts e
      retry
    end
    job_name
  end

  def render(path)
    data = File.read(File.expand_path(path))
    ERB.new(data).result(binding)
  end
end
