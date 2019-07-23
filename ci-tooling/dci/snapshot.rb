#!/usr/bin/env ruby

require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'date'
require 'thwait'
require 'logger'
require 'logger/colors'
require 'set'
require 'pp'

options = OpenStruct.new
options.repos = nil
options.all = false
options.host = 'localhost'
options.port = '8080'
options.distribution = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] --repo yolo"

  opts.on('-r', '--repo regex', String, 'Regex to filter out repos') do |v|
    options.regex = v
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end

  opts.on('-d', '--distribution DIST', 'Override distribution in released repository') do |v|
    options.distribution = v
  end
end
parser.parse!

raise parser.help if options.regex.nil?

if options.gateway
  case options.gateway.scheme
  when 'ssh'
    gateway = Net::SSH::Gateway.new(options.gateway.host, options.gateway.user)
    options.port = gateway.open('localhost', options.gateway.port)
  else
    raise 'Gateway scheme not supported'
  end
end

Aptly.configure do |config|
  config.host = options.host
  config.port = options.port
end

Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'snapshotter'
  l.level = Logger::INFO
end


options.repos = Aptly::Repository.list.collect do |repo|
  next if repo.Name.include?('old')
  repo if /#{options.regex}/ =~ repo.Name
end
options.repos.compact!

stamp = DateTime.now.strftime("%Y%m%d.%H%M")

opts = {}
opts[:Distribution] = options.distribution
opts[:Architectures] = %w(amd64 armhf arm64 i386 all source)
opts[:ForceOverwrite] = true
opts[:SourceKind] = 'snapshot'
@snapshots = []

options.repos.each do |repo|
  @log.info "Phase 1: Snapshotting #{repo.Name}"
  snapshot =
    if repo.packages.empty?
      Aptly::Snapshot.create("#{repo.Name}_#{options.distribution}_#{stamp}", opts)
    else
      # component = repo.Name.match(/(.*)-netrunner-backports/)[1].freeze
      repo.snapshot("#{repo.Name}_#{options.distribution}_#{stamp}", opts)
    end
  snapshot.DefaultComponent = repo.DefaultComponent
  @snapshots << snapshot
  @log.info 'Phase 1: Snapshotting complete'
end

@log.info 'Phase 2: Publishing of snapshots'
@sources = @snapshots.collect do |snap|
  { Name: snap.Name, Component: snap.DefaultComponent }
end

@s3 = Aptly::PublishedRepository.list.select do |x|
  !x.Storage.empty? && (x.SourceKind == 'snapshot') &&
    (x.Distribution == opts[:Distribution]) && (x.Prefix == 'netrunner')
end

if @s3.empty?
  puts @sources
  Aptly.publish(@sources, 's3:ds9-eu:netrunner', 'snapshot', opts)
  @log.info("Snapshots published")
elsif @s3.count == 1
  pubd = @s3[0]
  pubd.update!(Snapshots: @sources, ForceOverwrite: true)
  @log.info("Snapshots updated")
end
