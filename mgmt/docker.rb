#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/mobilekci'
require_relative '../ci-tooling/lib/nci'
require_relative '../lib/mgmt/deployer'

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

debian_series = DCI.series.keys
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
  next if status.success?
  # Don't fail on unstable as apparently we don't need it anyway.
  # <shadeslayer> well, it'll be fixed as soon as Debian unstable gets fixed?
  next if pid_map[pid] == 'debian-unstable'
  puts "ERROR: Creating container for #{pid_map[pid]} failed"
  exit_status = 1
end

exit exit_status
