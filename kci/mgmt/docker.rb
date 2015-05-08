#!/usr/bin/env ruby

require 'docker'
require 'erb'
require 'logger'
require 'logger/colors'

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
# FIXME: we completely ignore errors
c.stop!
# FIXME: we are leaking images...
# dockerfile build will reuse the original image that matches the file, essentially
# rolling back the bundle step, the only possible way to work around this is
# with COPY but that only wants relative paths, so we'd have to build from a tar
# which is slightly meh and a bit trickier.
c.commit(repo: REPO, tag: 'latest', comment: 'autodeploy', author: 'Kubuntu CI <sitter@kde.org>')
# p new_i.tag(repo: REPO, tag: 'latest', force: true)
c.remove
