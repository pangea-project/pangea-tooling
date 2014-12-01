require 'jenkins_api_client'
require 'thwait'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/jenkins'

$jenkins_template_path = File.expand_path(File.dirname(File.dirname(__FILE__))) + '/jenkins-templates'

########################

projects = Projects.new

########################

$jenkins = new_jenkins
type = 'unstable'
dist = 'vivid'
child_dists = ['utopic']

def job_name?(dist, type, name)
    return "#{dist}_#{type}_#{name}"
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
        raise 'Unknown SCM type ' + scm.type
    end
    xml.gsub!('@URL@', scm.url)
    xml.gsub!('@BRANCH@', scm.branch)

    return xml
end

def create_or_update(orig_xml_config, args = {})
    xml_config = orig_xml_config.dup
    xml_config.gsub!('@NAME@', args[:name] ||= '')
    xml_config.gsub!('@COMPONENT@', args[:component] ||= '')
    xml_config.gsub!('@TYPE@', args[:type] ||= '')
    xml_config.gsub!('@DIST@', args[:dist] ||= '')
    xml_config.gsub!('@DISABLED@', args[:disabled] ||= 'false')
    xml_config.gsub!('@DEPS@', args[:dependencies] ||= '') # Triggers always
    xml_config.gsub!('@DEPENDEES@', args[:dependees] ||= '') # Doesn't trigger
    xml_config.gsub!('@DAILY_TRIGGER@', args[:daily_trigger] ||= '')
    xml_config.gsub!('@DOWNSTREAM_TRIGGERS@', args[:downstream_triggers] ||= '') # Triggers on somewhat more advanced conditions
    xml_config.gsub!('@PACKAGING_BRANCH@', args[:packaging_branch] ||= 'kubuntu_unstable')
    xml_config.gsub!('@ARCHITECTURE@', args[:architecture] ||= '')

    xml_config.gsub!('@UPSTREAM_SCM@', sub_upstream_scm(args[:upstream_scm]))

    job_name = args[:job_name]
    job_name ||= job_name?(args[:dist], args[:type], args[:name])
    begin
        $jenkins.job.create_or_update(job_name, xml_config)
    rescue
        retry
    end
    return job_name
end

all_dist_jobs = []

# Update super triggers.
all_dists = child_dists.dup << dist
all_dists.each do |dist|
    # Sort the projects by their dependencies, less dependencies first.
    # This allows us to write sorted entries to jenkins which then triggers
    # the jobs in order and make sure that packages lower in the dep tree
    # are built first.
    projects.sort! { |x, y| x.dependencies.size <=> y.dependencies.size }
    downstreams = []
    projects.each do |project|
        downstreams << job_name?(dist, type, project.name)
    end
    downstreams.compact!
    all_dist_jobs.unshift("mgmt_build_#{dist}_#{type}")
    create_or_update(File.read("#{$jenkins_template_path}/mgmt-build.xml"), 
                     :job_name => all_dist_jobs.first,
                     :daily_trigger => '',
                     :downstream_triggers => downstreams.join(', '))
end

# Update the progenitor itsef.
create_or_update(File.read("#{$jenkins_template_path}/mgmt-progenitor.xml"), 
                 :job_name => "mgmt_progenitor",
                 :daily_trigger => '0 0 * * *',
                 :downstream_triggers => all_dist_jobs.join(', '))

$merger_jobs_queue = Queue.new

def add_project(project)
    puts "...#{project.name}..."

    # FIXME: codecopy from global scope
    type = 'unstable'
    dist = 'vivid'
    child_dists = ['utopic']

    # Translate dependencies to normalized job form.
    dependencies = project.dependencies.dup || []
    dependencies.collect! do |dep|
        dep = job_name?(dist, type, dep)
    end
    dependencies.compact!

    # Translate dependees to normalized job form.
    dependees = project.dependees.dup || []
    dependees.collect! do |dependee|
        dependee = job_name?(dist, type, dependee)
    end
    dependees.compact!

    # Manually add child_dist jobs as downstream triggers
    downstream_triggers = []
    child_dists.each do |child_dist|
        downstream_triggers << job_name?(child_dist, type, project.name)
    end
    downstream_triggers.compact!

    # Merger
    merger_name = "merger_#{project.name}"
    $merger_jobs_queue << merger_name
    job_name = create_or_update(File.read("#{$jenkins_template_path}/merger.xml"),
        :job_name => merger_name,
        :name => project.name,
        :component => project.component,
        :type => type,
        :dist => dist,
    )

    job_name = create_or_update(File.read("#{$jenkins_template_path}/trig-git.xml"),
        :name => project.name,
        :component => project.component,
        :type => type,
        :dist => dist,
        :dependencies => dependencies.join(', '),
        :dependees => dependees.join(', '),
        :upstream_scm => project.upstream_scm
    )

    # Update child_dist jobs
    child_dists.each do |child_dist|
        # All child dists have a dep relationship of their own to the
        # respectively dependee jobs from master. So we build a
        # new dependee array for each child, this time referencing the child
        # rather than the master.
        # if A depends B then master_A depends master_B and child_A depends child_B.
        dependees = project.dependees.dup
        dependees.collect! do |dep|
            dep = job_name?(child_dist, type, dep)
        end
        dependees.compact!

        packaging_branch = 'kubuntu_unstable'
        if project.series_branches.include?("kubuntu_unstable_#{child_dist}")
           packaging_branch = "kubuntu_unstable_#{child_dist}"
        end

        # Child dists have no 
        create_or_update(File.read("#{$jenkins_template_path}/trig-git.xml"),
            :name => project.name,
            :component => project.component,
            :type => type,
            :dist => child_dist,
            :dependees => dependees.join(', '),
            :upstream_scm => project.upstream_scm,
            :packaging_branch => packaging_branch
        )
    end
end

project_queue = Queue.new
projects.each do |project|
    project_queue << project
end

threads = []
16.times do
    threads << Thread.new do
        while project = project_queue.pop(true) do
            begin
                add_project(project)
            rescue => e
                p e
                raise e
            end
        end
    end
end
ThreadsWait.all_waits(threads)

merger_jobs = []
while job = $merger_jobs_queue.pop(true) do
    merger_jobs << job
end rescue # pop raises exception when used non-blocking

# Meta merger
job_name = create_or_update(File.read("#{$jenkins_template_path}/mgmt-merger.xml"),
                            :job_name => 'mgmt_merger',
                            :downstream_triggers => merger_jobs.join(', '))

# Create ISO Builders.
all_dists.each do |dist|
    ['i386', 'amd64'].each do |arch|
        puts "...iso_#{dist}_#{type}_#{arch}..." 
        create_or_update(File.read("#{$jenkins_template_path}/iso.xml"),
                         :job_name => "iso_#{dist}_#{type}_#{arch}",
                         :architecture => arch,
                         :type => type,
                         :dist => dist)
    end
    puts "..iso_#{dist}_#{type}.."
    create_or_update(File.read("#{$jenkins_template_path}/iso-meta.xml"),
                     :job_name => "iso_#{dist}_#{type}",
                     :type => type,
                     :dist => dist)
end

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
