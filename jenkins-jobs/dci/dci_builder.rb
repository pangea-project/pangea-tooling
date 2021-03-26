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
  def self.job(project, type:, series:, architecture:, upload_map: nil)
    basename = basename(series, type, project.component, project.name)
    dependees = project.dependees.collect do |d|
      "#{basename(series, type, d.component, d.name)}_src"
    end.compact
    sourcer = DCISourcerJob.new(basename,
                             type: type,
                             series: series,
                             project: project)
    publisher = DCIPublisherJob.new(basename,
                                 type: type,
                                 series: series,
                                 dependees: dependees,
                                 component: project.component,
                                 upload_map: upload_map,
                                 architecture: architecture)
    binarier = DCIBinarierJob.new(basename,
                                 type: type,
                                 series: series,
                                 architecture: architecture)
    sourcer.trigger(binarier)
    binarier.trigger(publisher)
    [sourcer] + [binarier] + [publisher]
  end

  def self.basename(dist, type, component, name)
    "#{dist}_#{type}_#{component}_#{name}"
  end
end
