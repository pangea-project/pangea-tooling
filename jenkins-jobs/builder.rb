require_relative 'sourcer'
require_relative 'binarier'
require_relative 'publisher'

# Magic builder to create an array of build steps
class Builder
  def self.job(project, type:, distribution:, architectures:, upload_map: nil)
    basename = basename(distribution, type, project.component, project.name)

    dependees = project.dependees.collect do |d|
      "#{basename(distribution, type, project.component, d)}_src"
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
                                 upload_map: upload_map)
    binariers = architectures.collect do |architecture|
      binarier = BinarierJob.new(basename,
                                 type: type,
                                 distribution: distribution,
                                 architecture: architecture)
      sourcer.trigger(binarier)
      binarier.trigger(publisher)
      binarier
    end
    binariers + [sourcer, publisher]
  end

  def self.basename(dist, type, component, name)
    "#{dist}_#{type}_#{component}_#{name}"
  end
end
