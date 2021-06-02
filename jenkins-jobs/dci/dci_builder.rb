# frozen_string_literal: true
# require_relative 'sourcer'
# require_relative 'binarier'
# require_relative 'publisher'
# require_relative '../job'
# 
# # Magic builder to create an array of build steps
# # Fun story: ci_reporter uses builder, builder is Builder, can't have a class
# # called Builder or tests will fail. I do rather love my live. Also generic
# # names are really cool for shared artifacts such as gems. I always try to be
# # as generic as possible with shared names.
class DCIBuilderJobBuilder
#   def self.job(project, release_type:, series:, architecture:, upload_map: nil)
#     basename = basename(series, release_type, project.component, project.name)
# 
#     dependees = project.dependees.collect do |d|
#       "#{basename(series, release_type, d.component, d.name)}_src"
#     end.compact
#     sourcer = DCISourcerJob.new(
#       basename,
#       release_type: release_type,
#       series: series,
#       project: project)
#     publisher = DCIPublisherJob.new(
#       basename,
#       release_type: release_type,
#       series: series,
#       dependees: publisher_dependees,
#       component: project.component,
#       upload_map: upload_map,
#       architecture: architecture)
#     binarier = DCIBinarierJob.new(
#       basename,
#       release_type: release_type,
#       series: series,
#       architecture: architecture)
#     sourcer.trigger(binarier)
#     binarier.trigger(publisher)
# 
#     jobs = [sourcer, binarier, publisher ]
#     basename1 = jobs[0].job_name.rpartition('_')[0]
#     unless basename == basename1
#       raise "unexpected basename diff #{basename} v #{basename1}"
#     end
#   end
# 
  def self.basename(series, release_type, component, name)
    "#{series}_#{release_type}_#{component}_#{name}"
  end
end
