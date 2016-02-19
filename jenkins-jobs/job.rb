require_relative '../ci-tooling/lib/jenkins'
require_relative 'template'

# Base class for Jenkins jobs.
class JenkinsJob < Template
  # FIXME: redundant should be name
  attr_reader :job_name

  def initialize(job_name, template_name)
    @job_name = job_name
    super(template_name)
  end

  # Creates or updates the Jenkins job.
  # @return the job_name
  def update
    # FIXME: this should use retry_it
    xml = render_template
    begin
      print "Updating #{job_name}\n"
      xml_debug(xml) if @debug
      Jenkins.job.create_or_update(job_name, xml)
    rescue => e
      # FIXME: use retry_it to fail after a number of tries
      puts e
      retry
    end
    job_name
  end

  alias to_s job_name
  alias to_str to_s
end
