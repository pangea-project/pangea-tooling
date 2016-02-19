#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'
require 'ostruct'
require 'optparse'

require_relative '../lib/nci'

options = OpenStruct.new
parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] PROJECTNAME"

  opts.on('-p SOURCEPACKAGE', 'Source package name [default: ARGV[0]]') do |v|
    options.source = v
  end

  opts.on('--type [TYPE]', NCI.types, 'Choose type(s) to expunge') do |v|
    options.types ||= []
    options.types << v.to_s
  end

  opts.on('--dist [DIST]', NCI.series.keys.map(&:to_sym),
          'Choose series to expunge (or multiple)') do |v|
    options.dists ||= []
    options.dists << v.to_s
  end
end
parser.parse!

abort parser.help unless ARGV[0]
options.name = ARGV[0]

# Defaults
options.source ||= options.name
options.keep_merger ||= false
options.types ||= NCI.types
options.dists ||= NCI.series.keys

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

## JENKINS

require_relative '../lib/jenkins'

job_names = []
options.dists.each do |d|
  options.types.each do |t|
    job_names << "#{d}_#{t}_([^_]*)_#{options.name}"
  end
end

log.info 'JENKINS'
Jenkins.job.list_all.each do |name|
  match = false
  job_names.each do |regex|
    match = name.match(regex)
    break if match
  end
  next unless match
  log.info "-- deleting :: #{name} --"
  log.debug Jenkins.job.delete(name)
end

## APTLY

require 'aptly'
require 'net/ssh/gateway'

# SSH tunnel so we can talk to the repo
gateway = Net::SSH::Gateway.new('drax', 'root')
gateway.open('localhost', 9090, 9090)

Aptly.configure do |config|
  config.host = 'localhost'
  config.port = 9090
end

log.info 'APTLY'
Aptly::Repository.list.each do |repo|
  next unless options.types.include?(repo.Name)

  # Query all relevant packages.
  # Any package with source as source.
  query = "($Source (#{options.name}))"
  # Or the source itself
  query += " | (#{options.name} {source})"
  packages = repo.packages(q: query).compact.uniq
  next if packages.empty?

  log.info "Deleting packages from repo #{repo.Name}: #{packages}"
  repo.delete_packages(packages)
end
