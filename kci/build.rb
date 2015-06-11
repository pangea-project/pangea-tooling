#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/retry'
require_relative '../lib/docker/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

JENKINS_PATH = '/var/lib/jenkins'
# This is a valid path on the host forwarded into the container.
# Necessary because we stored some configs in there.
OLD_TOOLING_PATH = "#{JENKINS_PATH}/tooling"
# This is only a valid path in the container.
TOOLING_PATH = "#{JENKINS_PATH}/ci-tooling/kci"
SSH_PATH = "#{JENKINS_PATH}/.ssh"

COMPONENT = ENV.fetch('COMPONENT')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
JOB_NAME = ENV.fetch('JOB_NAME')

# Add additional heuristics to decide whether we want to build on armhf.
# FIXME: we really only ought to define some anchor points (e.g. kwin and
#   all_frameworks) and the rest should be figured out automatically. This is
#   presently a bit tricky since we'd have to traverse the downstreams to see
#   if we are in any way related to one of the anchor points
MOBILE_JOBS = %w(kwin kwayland plasma-workspace libkscreen baloo kfilemetadata libksysguard kaccounts-integration kdecoration koko plasma-nm kaccounts-integration)
armit = false
if KCI.latest_series != DIST && TYPE == 'unstable'
  if COMPONENT == 'frameworks'
    armit = true
  else
    MOBILE_JOBS.each do |name|
      # FIXME: super fugly, job possibly should export the source name
      armit = true if JOB_NAME.end_with?("_#{name}")
    end
  end
end
ENV['ENABLED_EXTRA_ARCHITECTURES'] = 'armhf' if armit

FileUtils.rm_rf(['_anchor-chain'] + Dir.glob('logs/*') + Dir.glob('build/*'))

binds =  [
  "#{OLD_TOOLING_PATH}:#{OLD_TOOLING_PATH}",
  "#{SSH_PATH}:#{SSH_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = Containment.new(JOB_NAME, image: "jenkins/#{DIST}_#{TYPE}", binds: binds)
Retry.retry_it(times: 2, errors: [Docker::Error::NotFoundError]) do
  status_code = c.run(Cmd: ["#{TOOLING_PATH}/builder.rb", JOB_NAME, Dir.pwd])
  exit status_code unless status_code == 0
end

series = KCI.series.dup
series = series.sort_by { |_, version| Gem::Version.new(version) }.to_h
if DIST == series[-1]
  Dir.chdir('packaging') do
    system("git push packaging HEAD:kubuntu_#{TYPE}")
  end
end

exec('/var/lib/jenkins/tooling3/ci-tooling/kci/ppa-copy-package.rb')
