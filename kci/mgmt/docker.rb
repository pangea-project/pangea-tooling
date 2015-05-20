#!/usr/bin/env ruby

require 'docker'
require 'erb'
require 'logger'
require 'logger/colors'

def cleanup_dangling_things
  # Remove exited jenkins containers.
  containers = Docker::Container.all(all: true,
                                     filters: '{"status":["exited"]}')
  containers.each do |container|
    image = container.info.fetch('Image') { nil }
    unless image
      abort 'While cleaning up containers we found a container that has no' \
            " image associated with it. This should not happen: #{container}"
    end
    repo, _tag = Docker::Util.parse_repo_tag(image)
    if repo.start_with?('jenkins/')
      begin
        @log.warn "Removing container #{container.id}"
        container.remove
      rescue Docker::Error => e
        @log.warn 'Removing failed, continuing.'
        @log.warn e
      end
    end
  end

  # Remove all dangling images. It doesn't appear to be documented what
  # exactly a dangling image is, but from looking at the image count of both
  # a dangling query and a regular one I am infering that dangling images are
  # images that are none:none AND are not intermediates of another image
  # (whatever an intermediate may be). So, dangling is a subset of all
  # none:none images.
  # To make sure we get rid of everything we are running a dangling remove
  # and hope it does something worthwhile.
  # Docker::Image.all(all: true, filters: '{"dangling":["true"]}').each(&:delete)
  Docker::Image.all(all: true).each do |image|
    tags = image.info.fetch('RepoTags') { nil }
    next unless tags
    none_tags_only = true
    tags.each do |str|
      repo, tag = Docker::Util.parse_repo_tag(str)
      if repo != '<none>' && tag != '<none>'
        none_tags_only = false
        break
      end
    end
    next unless none_tags_only # Image used by something.
    begin
      @log.warn "Removing image #{image.id}"
      image.delete
    rescue Docker::Error::ConflictError
      @log.warn 'There was a conflict error, continuing.'
    rescue Docker::Error => e
      @log.warn 'Removing failed, continuing.'
      @log.warn e
    end
  end
end

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
REPO = "jenkins/#{NAME}"
TAG = 'latest'
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

# Disabled because we should not be leaking. And this has reentrancy problems
# where another deployment can cleanup our temporary container/image...
# cleanup_dangling_things

# create base
unless Docker::Image.exist?(REPO_TAG)
  Docker::Image.create(fromImage: "ubuntu:#{VERSION}", tag: REPO_TAG)
end

# Take the latest image which either is the previous latest or a completely
# prestine fork of the base ubuntu image and deploy into it.
# FIXME use containment here probably
c = Docker::Container.create(Image: REPO_TAG,
                             WorkingDir: ENV.fetch('HOME'),
                             Cmd: ['sh', '/var/lib/jenkins/tooling-pending/deploy_in_container.sh'])
c.start(Binds: ['/var/lib/jenkins/tooling-pending:/var/lib/jenkins/tooling-pending'],
        Ulimits: [{ Name: 'nofile', Soft: 1024, Hard: 1024 }])
c.attach do |_stream, chunk|
  puts chunk
  STDOUT.flush
end
# FIXME: we are completely ignore errors
c.stop!

# Flatten the image by piping a tar export into a tar import.
# Flattening essentially destroys the history of the image. By default docker
# will however stack image revisions ontop of one another. Namely if we have
# abc and create a new image edf, edf will be an AUFS ontop of abc. While this
# is probably useful if one doesn't commit containers repeatedly for us this
# is pretty crap as we have massive turn around on images.
@log.warn 'Flattening latest image by exporting and importing it.' \
          ' This can take a while.'
require 'thwait'

rd, wr = IO.pipe
@i = nil

Thread.abort_on_exception = true
read_thread = Thread.new do
  @i = Docker::Image.import_stream do
    rd.read(1000).to_s
  end
  @log.warn 'Import complete'
  rd.close
end
write_thread = Thread.new do
  c.export do |chunk|
    wr.write(chunk)
  end
  @log.warn 'Export complete'
  wr.close
end
ThreadsWait.all_waits(read_thread, write_thread)

c.remove
begin
  previous_image = Docker::Image.get(REPO_TAG)
  previous_image.delete
rescue Docker::Error::NotFoundError
  @log.warn 'There is no previous image, must be a new build.'
rescue Docker::Error::ConflictError
  @log.warn 'Could not remove old latest image, supposedly it is still used'
end
@i.tag(repo: REPO, tag: TAG, force: true)

# Disabled because we should not be leaking. And this has reentrancy problems
# where another deployment can cleanup our temporary container/image...
# cleanup_dangling_things
