#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

JENKINS_PATH = '/var/lib/jenkins'
# This is a valid path on the host forwarded into the container.
# Necessary because we stored some configs in there.
OLD_TOOLING_PATH = "#{JENKINS_PATH}/tooling"
# This is only a valid path in the container.
TOOLING_PATH = "#{JENKINS_PATH}/ci-tooling/kci"
SSH_PATH = "#{JENKINS_PATH}/.ssh"

DIST = ENV.fetch('DIST')
NAME = ENV.fetch('NAME')
TYPE = ENV.fetch('TYPE')
JOB_NAME = ENV.fetch('JOB_NAME')

# TODO:
# function finish {
#     # Let's not fail here since it does not contribute to overall build status
#     lxc-stop -n $CNAME || true
#     lxc-wait -n $CNAME --state=STOPPED --timeout=30 || true
#     lxc-destroy -n $CNAME || true
# }
# trap finish EXIT

FileUtils.rm_rf(['_anchor-chain'] + Dir.glob('logs/*') + Dir.glob('build/*'))

@log = Logger.new(STDERR)
@log.level = Logger::INFO

# Debug Thread
Thread.new do
  Docker::Event.stream do |event|
    @log.warn event
  end
end

args = {
  name: JOB_NAME,
  Image: "jenkins/#{DIST}_#{TYPE}",
  Volumes: {
    OLD_TOOLING_PATH => {},
    SSH_PATH => {},
    Dir.pwd => {}
  },
  WorkingDir: Dir.pwd,
  Cmd: ["#{TOOLING_PATH}/builder.rb", JOB_NAME, Dir.pwd]
}

begin
  c = Docker::Container.get(JOB_NAME)
  @log.info 'Cleaning up previous container.'
  c.kill!
  c.remove
rescue Docker::Error::NotFoundError
  @log.info 'Not cleaning up, no previous container found.'
end

c = Docker::Container.create(args)
c.rename(JOB_NAME)

Thread.new do
  # The log attach is threaded because
  # - attaching after start might attach to what is already stopped again in
  #   which case attach runs until timeout
  # - after start we do an explicit wait to get the correct status code so
  #   we can exit accordingly
  c.attach do |_stream, chunk|
    puts chunk
    STDOUT.flush
  end
end

binds =  [
  "#{OLD_TOOLING_PATH}:#{OLD_TOOLING_PATH}",
  "#{SSH_PATH}:#{SSH_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]
c.start(Binds: binds)
status_code = c.wait.fetch('StatusCode', 1)
exit status_code unless status_code == 0

if DIST == 'vivid'
  Dir.chdir('packaging') do
    system("git push packaging HEAD:kubuntu_#{TYPE}")
  end
end

exec('/var/lib/jenkins/tooling3/ci-tooling/kci/ppa-copy-package.rb')
