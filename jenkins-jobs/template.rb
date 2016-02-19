require 'erb'
require 'pathname'

# Base class for job template.
class Template
  # [String] Directory with config files. Absolute.
  attr_reader :config_directory
  # [String] Template file for this job. Absolute.
  attr_reader :template_path

  def initialize(template_name)
    @config_directory = "#{@@flavor_dir}/config/"
    @template_directory = "#{@@flavor_dir}/templates/"
    @template_path = "#{@template_directory}#{template_name}"
    unless File.exist?(@template_path)
      raise "Template #{template_name} not found at #{@template_path}"
    end
  end

  def self.flavor_dir=(dir)
    # This is handled as a class variable because we want all instances of
    # JenkinsJob to have the same flavor set. Class instance variables OTOH
    # would need additional code to properly apply it to all instances, which
    # is mostly useless.
    @@flavor_dir = dir # rubocop:disable Style/ClassVars
  end

  def self.flavor_dir
    @@flavor_dir
  end

  def render_template
    render(@template_path)
  end

  def render(path)
    data = if Pathname.new(path).absolute?
             File.read(path)
           else
             File.read("#{@template_directory}/#{path}")
           end
    ERB.new(data).result(binding)
  end

  private

  def xml_debug(data)
    require 'rexml/document'
    doc = REXML::Document.new(data)
    REXML::Formatters::Pretty.new.write(doc, $stdout)
  end
end
