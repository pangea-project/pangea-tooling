#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/dci'
require_relative '../lib/nci'
require_relative '../lib/mgmt/deployer'

class TeeLog
  def initialize(*ios, prefix: nil)
    @ios = ios
    @stderr = STDERR # so we can log unexpected method calls in method_missing
    @prefix = prefix
  end

  def write(*args)
    @ios.each { |io| io.write("{#{@prefix}} ", *args) }
  end

  def close
    @ios.each(&:close)
  end

  def method_missing(*args)
    @stderr.puts "TeeLog not implemented: #{args}"
  end
end

def setup_logger(name)
  log_path = "#{Dir.pwd}/#{name}.log"
  warn "logging to #{log_path}"
  tee = TeeLog.new(STDOUT, File.open(log_path, "a"), prefix: name)
  $stdout = tee
  $stderr = tee
end

pid_map = {}

p ENV
warn "debian only: #{ENV.include?('PANGEA_DEBIAN_ONLY')}"
warn "ubuntu only: #{ENV.include?('PANGEA_UBUNTU_ONLY')}"
warn "nci current?: #{ENV.include?('PANGEA_NEON_CURRENT_ONLY')}"

ubuntu_series = NCI.series.keys
ubuntu_series = [NCI.current_series] if ENV.include?('PANGEA_NEON_CURRENT_ONLY')
ubuntu_series = [] if ENV.include?('PANGEA_DEBIAN_ONLY')
ubuntu_series.each_index do |index|
  series = ubuntu_series[index]
  origins = ubuntu_series[index + 1..-1]
  name = "ubuntu-#{series}"
  warn "building #{name}"
  pid = fork do
    setup_logger(name)
    d = MGMT::Deployer.new('ubuntu', series, origins)
    d.run!
    exit
  end

  pid_map[pid] = "ubuntu-#{series}"
end

=begin
FIXME DCI disabled jriddell 2021-06-07 due to broken deployments
debian_series = DCI.version_codenames
debian_series = [] if ENV.include?('PANGEA_UBUNTU_ONLY')
debian_series.each do |series|
  name = "debian-#{series}"
  warn "building #{name}"
  pid = fork do
    setup_logger(name)
    d = MGMT::Deployer.new('debian', series)
    d.run!
    exit
  end

  pid_map[pid] = "debian-#{series}"
end
=end


ec = Process.waitall

exit_status = 0

ec.each do |pid, status|
  next if status.success?

  puts "ERROR: Creating container for #{pid_map[pid]} failed"
  exit_status = 1
end

exit exit_status
