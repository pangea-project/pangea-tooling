#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/mobilekci'
require_relative '../ci-tooling/lib/nci'
require_relative '../lib/mgmt/deployer'

class TeeLog
  def initialize(*ios)
    @ios = ios
    @stderr = STDERR # so we can log unexpected method calls in method_missing
  end

  def write(*args)
    @ios.each { |io| io.write(*args) }
  end

  def close
    @ios.each(&:close)
  end

  def method_missing(*args)
    @stderr.puts "TeeLog not implemented: #{args}"
  end
end

# NCI and mobile *can* have series overlap, they both use ubuntu as a base
# though, so union the series keys and create images for the superset.

pid_map = {}

p ENV
warn "debian only: #{ENV.include?('PANGEA_DEBIAN_ONLY')}"
warn "ubuntu only: #{ENV.include?('PANGEA_UBUNTU_ONLY')}"
warn "nci current?: #{ENV.include?('PANGEA_NEON_CURRENT_ONLY')}"

ubuntu_series = (MCI.series.keys | NCI.series.keys)
ubuntu_series = [NCI.current_series] if ENV.include?('PANGEA_NEON_CURRENT_ONLY')
ubuntu_series = [] if ENV.include?('PANGEA_DEBIAN_ONLY')
ubuntu_series.each_index do |index|
  series = ubuntu_series[index]
  origins = ubuntu_series[index + 1..-1]
  log_path = "#{Dir.pwd}/ubuntu-#{series}.log"
  warn "building ubuntu #{series}; logging to #{log_path}"
  pid = fork do
    tee = TeeLog.new(STDOUT, File.open(log_path, "a"))
    $stdout = tee
    $stderr = tee
    d = MGMT::Deployer.new('ubuntu', series, origins)
    d.run!
  end

  pid_map[pid] = "ubuntu-#{series}"
end

debian_series = DCI.series.keys
debian_series = [] if ENV.include?('PANGEA_UBUNTU_ONLY')
debian_series.each do |series|
  log_path = "#{Dir.pwd}/debian-#{series}.log"
  warn "building debian #{series}; logging to #{log_path}"
  pid = fork do
    tee = TeeLog.new(STDOUT, File.open(log_path, "a"))
    $stdout = tee
    $stderr = tee
    d = MGMT::Deployer.new('debian', series)
    d.run!
  end

  pid_map[pid] = "debian-#{series}"
end

ec = Process.waitall

exit_status = 0

ec.each do |pid, status|
  next if status.success?
  puts "ERROR: Creating container for #{pid_map[pid]} failed"
  exit_status = 1
end

exit exit_status
