#!/usr/bin/env ruby

require_relative '../lib/mgmt/deployer'

KCI.series.keys.each do |k|
  fork do
    d = MGMT::Deployer.new('ubuntu', k)
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
