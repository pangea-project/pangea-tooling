#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/mobilekci'
require_relative '../lib/mgmt/deployer'

# KCI and mobile *can* have series overlap, they both use ubuntu as a base
# though, so union the series keys and create images for the superset.

pidMap = {}

ubuntu_series = (KCI.series.keys | MobileKCI.series.keys)
ubuntu_series.each_index do |index|
  series = ubuntu_series[index]
  origins = ubuntu_series[index + 1..-1]
  pid = fork do
          d = MGMT::Deployer.new('ubuntu', series, origins)
          d.run!
        end

  pidMap[pid] = "ubuntu-#{series}"
end

DCI.series.keys.each do |k|
  pid = fork do
          d = MGMT::Deployer.new('debian', k)
          d.run!
        end

  pidMap[pid] = "debian-#{k}"
end

ec = Process.waitall

status = 0

ec.each do |pid, status|
  unless status.success?
    puts "ERROR: Creating container for #{pidMap[pid]} failed"
    status = 1
  end
end

exit status
