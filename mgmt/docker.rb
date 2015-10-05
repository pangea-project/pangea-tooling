#!/usr/bin/env ruby

require_relative 'lib/mgmt/deployer'

KCI.series.keys.each do |k|
  d = MGMT::Deployer.new('ubuntu', k)
  d.run!
end

DCI.series.keys.each do |k|
  d = MGMT::Deployer.new('debian', k)
  d.run!
end
