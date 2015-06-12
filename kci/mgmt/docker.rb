#!/usr/bin/env ruby

require 'docker'
require 'erb'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/dpkg'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

$stdout = $stderr

NAME = ENV.fetch('NAME')
VERSION = ENV.fetch('VERSION')
REPO = "jenkins/#{NAME}"
TAG = 'latest'
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

# create base
unless Docker::Image.exist?(REPO_TAG)
  @log.info 'creating base docker image'
  ubuntu_image = "ubuntu:#{VERSION}"
  ubuntu_image = "armv7/armhf-ubuntu:#{VERSION}" if DPKG::HOST_ARCH == 'armhf'
  Docker::Image.create(fromImage: ubuntu_image).tag(repo: REPO, tag: TAG)
end

# Take the latest image which either is the previous latest or a completely
# prestine fork of the base ubuntu image and deploy into it.
# FIXME use containment here probably
@log.info 'creating container'
c = Docker::Container.create(Image: REPO_TAG,
                             WorkingDir: ENV.fetch('HOME'),
                             Cmd: ['sh', '/tooling-pending/deploy_in_container.sh'])
@log.info 'creating debug thread'
Thread.new do
  # :nocov:
  c.attach do |_stream, chunk|
    puts chunk
    STDOUT.flush
  end
  # :nocov:
end
@log.info 'starting container'
c.start(Binds: ["#{Dir.home}/tooling-pending:/tooling-pending"],
        Ulimits: [{ Name: 'nofile', Soft: 1024, Hard: 1024 }])
status_code = c.wait.fetch('StatusCode', 1)
fail 'status fucked' if status_code != 0
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
