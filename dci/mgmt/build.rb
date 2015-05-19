#!/usr/bin/env ruby
require 'erb'
require 'logger'
require 'logger/colors'
require 'tempfile'

require_relative '../../lib/docker/containment'
require_relative '../../ci-tooling/lib/retry'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

ARCH = RbConfig::CONFIG['host_cpu']
RELEASE = ENV.fetch('RELEASE')
JOB_NAME = ENV.fetch('JOB_NAME')
WORKSPACE = ENV.fetch('WORKSPACE')
JENKINS_HOME = ENV.fetch('JENKINS_HOME')
REPO = "ci-#{RELEASE}/#{ARCH}"
TAG = ENV.fetch('BUILD_NUMBER')
REPO_TAG = "#{REPO}:#{TAG}"

class Dockerfile
  attr_reader :series
  attr_reader :jenkins_home
  attr_reader :user

  def initialize
    @series = RELEASE
    @jenkins_home = JENKINS_HOME
    @user = 'debian' if ARCH == 'x86_64'
    @user = 'armbuild/debian' if ARCH == 'arm'
  end

  def render
    path = File.join(File.dirname(__FILE__), 'Dockerfile')
    ERB.new(File.read(path)).result(binding)
  end

  def self.render
    new.render
  end
end

def excavate_stdout(c)
  Thread.new do
    c.attach do |_stream, chunk|
      puts chunk
      STDOUT.flush
    end
  end
end

@log = Logger.new(STDERR)
@log.level = Logger::WARN

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

Docker::Image.build(Dockerfile.render, t: REPO_TAG, nocache: true) do |chunk|
  chunk = JSON.parse(chunk)
  keys = chunk.keys

  puts chunk['stream'] if keys.include?('stream')

  if keys.include?('error')
    @log.error chunk['error']
    @log.error chunk['errorDetail']
  end

  @log.info chunk['status'] if keys.include?('status')
end

@log.debug('Dockerfile successfully built')

cmd = "
set -ex
cd #{WORKSPACE}/tooling
git clean -dfx
bundler install
bundler list
bundler exec rake test
git config --global --unset url.git://anonscm.debian.org/pkg-kde/.insteadof
"

helper_script = "#{WORKSPACE}/helper.sh"
File.write(helper_script, cmd)

binds = ["#{WORKSPACE}:#{WORKSPACE}"]

c = Docker::Container.create(Image: REPO_TAG,
                             WorkingDir: WORKSPACE,
                             User: 'jenkins',
                             Cmd: ['/bin/bash', '-l',
                                   "#{WORKSPACE}/helper.sh"])
excavate_stdout(c)
c.start(Binds: binds)
status_code = c.wait.fetch('StatusCode', 1)
c.stop!
# WORKAROUND : This is a workaround for the following issues :
#               * https://github.com/docker/docker/issues/9665
#               * https://github.com/docker/docker/issues/7636
sleep 5
c.commit(repo: REPO, tag: 'interim', comment: 'autodeploy',
         author: 'Debian CI <rohan@garg.io>')

exit status_code unless status_code == 0

cmd = "
set -ex
# Remove gitconfig after we're done running tests
cp -aRv #{WORKSPACE}/tooling /opt/
"

helper_script = "#{WORKSPACE}/copier.sh"
File.write(helper_script, cmd)

c = Docker::Container.create(Image: "#{REPO}:interim",
                             WorkingDir: WORKSPACE,
                             Cmd: ['/bin/bash', '-l',
                                   "#{WORKSPACE}/copier.sh"],
                             User: 'root')
excavate_stdout(c)
c.start(Binds: binds)
status_code = c.wait.fetch('StatusCode', 1)
c.stop!

exit status_code unless status_code == 0

c.commit(repo: REPO, tag: 'latest', comment: 'autodeploy',
         author: 'Debian CI <rohan@garg.io>')

# FIXME: Cleanup
# Docker::Image.remove("#{REPO}:interim")
