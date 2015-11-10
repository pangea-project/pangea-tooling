#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/mobilekci'
require_relative '../lib/mgmt/deployer'

# KCI and mobile *can* have series overlap, they both use ubuntu as a base
# though, so union the series keys and create images for the superset.
ubuntu_series = (KCI.series.keys | MobileKCI.series.keys)
ubuntu_series.each_index do |index|
  series = ubuntu_series[index]
  origins = ubuntu_series[index + 1..-1]
  fork do
    d = MGMT::Deployer.new('ubuntu', series, origins)
    d.run!
  end
end

DCI.series.keys.each do |k|
  fork do
    d = MGMT::Deployer.new('debian', k)
    d.run!
  end
end

ec = Process.waitall

ec.each do |_, status|
  unless status.success?
    puts 'WARNING: One of the containers failed to build'
    exit 1
  end
end
