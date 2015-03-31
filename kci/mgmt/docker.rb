#!/usr/bin/env ruby

require 'docker'
require 'erb'
require 'logger'
require 'logger/colors'

class Dockerfile
  attr_reader :series

  def new
    @series = RELEASE
  end

  def render
    path = File.join(File.dirname(__FILE__), 'Dockerfile')
    ERB.new(File.read(path)).result(binding)
  end

  def self.render
    new.render
  end
end

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

NAME = ENV.fetch('NAME')
REPO = "jenkins/#{NAME}"
TAG = 'deploying'
REPO_TAG = "#{REPO}:#{TAG}"

@log = Logger.new(STDERR)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

Docker::Image.build(Dockerfile.render, t: REPO_TAG) do |chunk|
  chunk = JSON.parse(chunk)
  keys = chunk.keys
  if keys.include?('stream')
    puts chunk['stream']
  elsif keys.include?('error')
    @log.error chunk['error']
    @log.error chunk['errorDetail']
  elsif keys.include?('status')
    @log.info chunk['status']
  else
    fail "Unknown response type in #{chunk}"
  end
end

# Dockerfiles can not mount host paths, so instead manually conduct this step
# through an intermediate container. This containers is then commited to both
# deploying and latest. Such that we also can reuse the bundle install when
# re-deploying.

# FIXME: there should be a deploy target on rake or something to avoid having
# to write this shite here.=
cmd = <<EOF
  set -ex
  cd /var/lib/jenkins/tooling-pending
  bundle install --no-cache --local --frozen --system --without development test
  rm -rf /var/lib/jenkins/ci-tooling /var/lib/jenkins/.gem /var/lib/jenkins/.rvm
  cp -r /var/lib/jenkins/tooling-pending/ci-tooling /var/lib/jenkins/ci-tooling
EOF
helper_script = '/var/lib/jenkins/tooling-pending/_helper'
File.write(helper_script, cmd)

c = Docker::Container.create(Image: REPO_TAG,
                             WorkingDir: ENV.fetch('HOME'),
                             Cmd: ['sh', helper_script])

c.start(Binds: ['/var/lib/jenkins/tooling-pending:/var/lib/jenkins/tooling-pending'])
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
