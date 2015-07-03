require_relative 'sourcer'
require_relative 'binarier'
require_relative 'publisher'

# Magic builder to create an array of build steps
class Builder
  def self.job(project, type:, distribution:)
    basename = basename(distribution, type, project.name)
    dependees = project.dependees.collect do |d|
      "#{basename(distribution, type, d)}_src"
    end.compact
    sourcer = SourcerJob.new(basename, type: type, distribution: distribution, project: project)
    publisher = PublisherJob.new(basename, type: type, distribution: distribution, dependees: dependees)
    binariers = %w(amd64 armhf).collect do |architecture|
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

  def self.basename(dist, type, name)
    "#{dist}_#{type}_#{name}"
  end
end
