require 'jenkins_api_client'
require 'thwait'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/jenkins'
require 'json'

$jenkins_template_path = File.expand_path(File.dirname(File.dirname(__FILE__))) + '/jenkins-templates'

########################

projects = Projects.new(allow_custom_ci: true)

########################

type = ['source', 'binary', 'publish']
dist = ['unstable']
$jenkins_client_hash = {}

def job_name?(release, type, name)
  "#{name}_#{type}_#{release}"
end

def sub_upstream_scm(scm)
  return '' unless scm

  xml = nil
  case scm.type
  when 'git'
    xml = File.read("#{$jenkins_template_path}/upstream-scms/git.xml")
  when 'svn'
    xml = File.read("#{$jenkins_template_path}/upstream-scms/svn.xml")
  else
    fail 'Unknown SCM type ' + scm.type
  end
  xml.gsub!('@URL@', scm.url)
  xml.gsub!('@BRANCH@', scm.branch)

  return xml
end

def create_or_update(orig_xml_config, args = {})
  xml_config = orig_xml_config.dup
  xml_config.gsub!('@UPSTREAM_SCM@', sub_upstream_scm(args[:upstream_scm]))
  xml_config.gsub!('@PACKAGING_SCM@', args[:packaging_scm])
  xml_config.gsub!('@NAME@', args[:name] ||= '')
  xml_config.gsub!('@COMPONENT@', args[:component] ||= '')
  xml_config.gsub!('@UPLOAD_TARGET@', args[:upload_target] ||= 'plasma')
  xml_config.gsub!('@TYPE@', args[:type] ||= '')
  xml_config.gsub!('@DIST@', args[:dist] ||= '')
  xml_config.gsub!('@DEPS@', args[:dependencies] ||= '') # Triggers always
  xml_config.gsub!('@DEPENDEES@', args[:dependees] ||= '') # Doesn't trigger
  xml_config.gsub!('@DAILY_TRIGGER@', args[:daily_trigger] ||= '')
  xml_config.gsub!('@DOWNSTREAM_TRIGGERS@', args[:downstream_triggers] ||= '') # Triggers on somewhat more advanced conditions

  # Workaround for kate/konsole in Debian at the moment
  # konsole/kate5-data can't be co installed with kde-runtime/dolphin
  # at the moment so lets use the utopic_unstable branch for now since
  # that has the relevant packaging to make it co installable
  if %w(kate konsole).include?(args[:name])
    args[:packaging_branch] = 'kubuntu_unstable_utopic'
  end
  xml_config.gsub!('@PACKAGING_BRANCH@', args[:packaging_branch] ||= 'kubuntu_unstable')
  xml_config.gsub!('@ARCHITECTURE@', args[:architecture] ||= '')

  job_name = args[:job_name]
  job_name ||= job_name?(args[:dist], args[:type], args[:name])

  begin
    $jenkins_client_hash[args[:upload_target]] ||= JenkinsApi::Client.new(:jenkins_path => "/job/#{args[:upload_target]}/")
    $jenkins_client_hash[args[:upload_target]].job.create_or_update(job_name, xml_config)
  rescue
    retry
  end
  return job_name
end

def add_project(project, upload_info)
  type = %w(source binary publish)
  dist = ['unstable']
  puts "...#{project.name}..."

  dist.each do |release|
    type.each do |job_type|
      # Translate dependencies to normalized job form.
      dependencies = project.dependencies.dup || []
      dependencies.collect! do |dep|
        dep = job_name?(release, type, dep)
      end
      dependencies.compact!

      # Translate dependees to normalized job form.
      dependees = project.dependees.dup || []
      dependees.collect! do |dependee|
        dependee = job_name?(release, job_type, dependee)
      end
      dependees.compact!

      job_name = create_or_update(File.read("#{$jenkins_template_path}/dci_#{job_type}.xml"),
      :name => project.name,
      :component => project.component,
      :type => job_type,
      :dist => release,
      :dependencies => dependencies.join(', '),
      :dependees => dependees.join(', '),
      :upstream_scm => project.upstream_scm,
      :packaging_scm => project.packaging_scm,
      :upload_target => upload_info[project.component]
      )
    end
  end
end

project_queue = Queue.new
projects.each do |project|
  project_queue << project
end

threads = []
upload_info = JSON::parse(File.read('data/uploadtarget.json'))

6.times do
  threads << Thread.new do
    while project = project_queue.pop(true) do
      begin
        add_project(project, upload_info)
      rescue => e
        p e
        raise e
      end
    end
  end
end
ThreadsWait.all_waits(threads)

$jenkins = JenkinsApi::Client.new
# Autoinstall all possibly used plugins.
installed_plugins = $jenkins.plugin.list_installed.keys
Dir.glob('jenkins-templates/**/**.xml').each do |path|
  File.readlines(path).each do |line|
    match = line.match(/.*plugin="(.+)".*/)
    next unless match and match.size == 2
    plugin = match[1].split('@').first
    next if installed_plugins.include?(plugin)
    puts "--- Installing #{plugin} ---"
    $jenkins.plugin.install(plugin)
  end
end
