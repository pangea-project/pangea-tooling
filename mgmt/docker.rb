#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/mobilekci'
require_relative '../ci-tooling/lib/nci'
require_relative '../lib/mgmt/deployer'

require 'jenkins_api_client'

JOB_NAME = ENV.fetch('JOB_NAME')
remotes = %w(dci.pangea.pub)

remotes.each do |server|
  fork do
    client = JenkinsApi::Client.new(server_ip: server)
    while client.queue.list.include?(JOB_NAME)
      puts "Waiting for #{server} to start mgmt job"
      sleep 10
    end
  end
end

Process.waitall

# KCI and mobile *can* have series overlap, they both use ubuntu as a base
# though, so union the series keys and create images for the superset.

pid_map = {}

ubuntu_series = (KCI.series.keys | MCI.series.keys | NCI.series.keys)
ubuntu_series.each_index do |index|
  series = ubuntu_series[index]
  origins = ubuntu_series[index + 1..-1]
  pid = fork do
    d = MGMT::Deployer.new('ubuntu', series, origins)
    d.run!
  end

  pid_map[pid] = "ubuntu-#{series}"
end

debian_series = (DCI.series.keys | NDCI.series.keys)
debian_series.each do |k|
  pid = fork do
    d = MGMT::Deployer.new('debian', k)
    d.run!
  end

  pid_map[pid] = "debian-#{k}"
end

ec = Process.waitall

exit_status = 0

ec.each do |pid, status|
  unless status.success?
    puts "ERROR: Creating container for #{pid_map[pid]} failed"
    exit_status = 1
  end
end

exit exit_status
