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
    binarier = BinarierJob.new(basename, type: type, distribution: distribution)
    sourcer.trigger(binarier)
    publisher = PublisherJob.new(basename, type: type, distribution: distribution, dependees: dependees)
    binarier.trigger(publisher)
    [sourcer, binarier, publisher]
  end

  def self.basename(dist, type, name)
    "#{dist}_#{type}_#{name}"
  end
end
