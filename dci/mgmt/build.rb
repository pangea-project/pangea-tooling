#!/usr/bin/env ruby
require 'erb'
require 'logger'
require 'logger/colors'
require 'tempfile'

require_relative '../../lib/docker/containment'
require_relative '../../ci-tooling/lib/retry'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

RELEASE = ENV.fetch('RELEASE')
JOB_NAME = ENV.fetch('JOB_NAME')
WORKSPACE = ENV.fetch('WORKSPACE')
JENKINS_HOME = ENV.fetch('JENKINS_HOME')
REPO = "ci/#{RbConfig::CONFIG['host_cpu']}"
TAG = ENV.fetch('BUILD_NUMBER')
REPO_TAG = "#{REPO}:#{TAG}"

class Dockerfile
  attr_reader :series
  attr_reader :jenkins_home
  attr_reader :user

  def initialize
    @series = RELEASE
    @jenkins_home = JENKINS_HOME
    @user = 'debian' if RbConfig::CONFIG['host_cpu'] == 'x86_64'
    @user = 'armbuild/debian' if RbConfig::CONFIG['host_cpu'] == 'arm'
  end

  def render
    path = File.join(File.dirname(__FILE__), 'Dockerfile')
    ERB.new(File.read(path)).result(binding)
  end

  def self.render
    new.render
  end
end

@log = Logger.new(STDERR)
@log.level = Logger::DEBUG

Thread.new do
  Docker::Event.stream { |event| @log.debug event }
end

Docker::Image.build(Dockerfile.render, t: REPO_TAG) do |chunk|
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

# FIXME: Hard coded paths
cmd = "
set -ex
cd #{WORKSPACE}/tooling
git clean -dfx
bundler install
bundler list
bundler exec rake test
"

helper_script = "#{WORKSPACE}/helper.sh"
File.write(helper_script, cmd)

binds = ["#{WORKSPACE}:#{WORKSPACE}",
         "#{JENKINS_HOME}/.ssh:#{JENKINS_HOME}/.ssh"]

c = Docker::Container.create(Image: REPO_TAG,
                             WorkingDir: WORKSPACE,
                             Cmd: ['/bin/bash', '-l',
                                   "#{WORKSPACE}/helper.sh"])

c.start(Binds: binds)
Thread.new do
  c.attach do |_stream, chunk|
    puts chunk
    STDOUT.flush
  end
end
status_code = c.wait.fetch('StatusCode', 1)
c.stop!

c.commit(repo: REPO, tag: 'latest', comment: 'autodeploy',
         author: 'Debian CI <rohan@garg.io>') unless status_code == 0

exit status_code
