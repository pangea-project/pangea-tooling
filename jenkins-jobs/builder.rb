# frozen_string_literal: true
require_relative 'sourcer'
require_relative 'binarier'
require_relative 'publisher'

# Magic builder to create an array of build steps
# Fun story: ci_reporter uses builder, builder is Builder, can't have a class
# called Builder or tests will fail. I do rather love my live. Also generic
# names are really cool for shared artifacts such as gems. I always try to be
# as generic as possible with shared names.
class BuilderJobBuilder
  def self.job(project, type:, distribution:, architectures:, upload_map: nil)
    basename = basename(distribution, type, project.component, project.name)

    dependees = project.dependees.collect do |d|
      "#{basename(distribution, type, d.component, d.name)}_src"
    end.compact
    sourcer = SourcerJob.new(basename,
                             type: type,
                             distribution: distribution,
                             project: project)
    publisher = PublisherJob.new(basename,
                                 type: type,
                                 distribution: distribution,
                                 dependees: dependees,
                                 component: project.component,
                                 upload_map: upload_map,
                                 architectures: architectures)
    binariers = architectures.collect do |architecture|
      binarier = BinarierJob.new(basename,
                                 type: type,
                                 distribution: distribution,
                                 architecture: architecture)
      sourcer.trigger(binarier)
      binarier.trigger(publisher)
      binarier
    end
    [sourcer] + binariers + [publisher]
  end

  def self.basename(dist, type, component, name)
    "#{dist}_#{type}_#{component}_#{name}"
  end
end
