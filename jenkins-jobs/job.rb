require 'erb'
require 'pathname'

require_relative '../ci-tooling/lib/jenkins'

# Base class for Jenkins jobs.
class JenkinsJob
  # FIXME: redundant should be name
  attr_reader :job_name

  # [String] Directory with config files. Absolute.
  attr_reader :config_directory
  # [String] Template file for this job. Absolute.
  attr_reader :template_path

  def initialize(job_name, template_name)
    @job_name = job_name
    file_directory = File.expand_path(File.dirname(__FILE__))
    @config_directory = "#{file_directory}/config/"
    @template_directory = "#{file_directory}/templates/"
    @template_path = "#{@template_directory}#{template_name}"
    fail "Template #{template_name} not found" unless File.exist?(@template_path)
  end

  # Creates or updates the Jenkins job.
  # @return the job_name
  def update
    xml = render_template
    begin
      print "Updating #{job_name}\n"
      xml_debug(xml) if @debug
      Jenkins.job.create_or_update(job_name, xml)
    rescue => e
      puts e
      retry
    end
    job_name
  end

  def render_template
    render(@template_path)
  end

  def render(path)
    if Pathname.new(path).absolute?
      data = File.read(path)
    else
      data = File.read("#{@template_directory}/#{path}")
    end
    ERB.new(data).result(binding)
  end

  alias_method :to_s, :job_name
  alias_method :to_str, :to_s

  private

  def xml_debug(data)
    require 'rexml/document'
    doc = REXML::Document.new(data)
    REXML::Formatters::Pretty.new.write(doc, STDOUT)
  end
end
