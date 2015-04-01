#!/usr/bin/env ruby

require_relative 'docker/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

JENKINS_PATH = '/var/lib/jenkins'
# This is a valid path on the host forwarded into the container.
# Necessary because we stored some configs in there.
OLD_TOOLING_PATH = "#{JENKINS_PATH}/tooling"
# This is only a valid path in the container.
TOOLING_PATH = "#{JENKINS_PATH}/ci-tooling/kci"
SSH_PATH = "#{JENKINS_PATH}/.ssh"

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
JOB_NAME = ENV.fetch('JOB_NAME')

FileUtils.rm_rf(['_anchor-chain'] + Dir.glob('logs/*') + Dir.glob('build/*'))

binds =  [
  "#{OLD_TOOLING_PATH}:#{OLD_TOOLING_PATH}",
  "#{SSH_PATH}:#{SSH_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = Containment.new(JOB_NAME, image: "jenkins/#{DIST}_#{TYPE}", binds: binds)
status_code = c.run(Cmd: ["#{TOOLING_PATH}/builder.rb", JOB_NAME, Dir.pwd])
exit status_code unless status_code == 0

if DIST == 'vivid'
  Dir.chdir('packaging') do
    system("git push packaging HEAD:kubuntu_#{TYPE}")
  end
end

exec('/var/lib/jenkins/tooling3/ci-tooling/kci/ppa-copy-package.rb')
