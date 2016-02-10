#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'
require 'ostruct'
require 'optparse'

require_relative '../lib/jenkins'
require_relative '../lib/kci'
require_relative '../lib/lp'

options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] PROJECTNAME"

  opts.on('-p SOURCEPACKAGE', 'Source package name [default: ARGV[0]]') do |v|
    options.source = v
  end

  opts.on('--keep-merger', 'Do not expunge merger') do
    options.keep_merger = true
  end

  opts.on('--type [TYPE]', KCI.types,
          'Choose type to expunge (or multiple)') do |v|
    options.types ||= []
    options.types << v.to_s
  end

  opts.on('--dist [DIST]', KCI.series.keys.map(&:to_sym),
          'Choose series to expunge (or multiple)') do |v|
    options.dists ||= []
    options.dists << v.to_s
  end
end.parse!

fail 'Need a project name as argument' unless ARGV[0]
options.name = ARGV[0]

# Defaults
options.source ||= options.name
options.keep_merger ||= false
options.types ||= KCI.types
options.dists ||= KCI.series.keys

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

## JENKINS

job_names = []
options.dists.each do |d|
  options.types.each do |t|
    job_names << "#{d}_#{t}_#{options.name}"
  end
end
job_names << "merger_#{options.name}" unless options.keep_merger

log.info 'JENKINS'
Jenkins.job.list_all.each do |name|
  next unless job_names.delete(name)
  log.info "-- deleting :: #{name} --"
  log.debug Jenkins.job.delete(name)
end

## PPA

# FIXME: code dupe in numerous tools that want to wipe
log.info 'PPA'
statuses = %w(Pending Published Superseded Obsolete)
Launchpad.authenticate
statuses.each do |status|
  options.types.each do |type|
    ppa = Launchpad::Rubber.from_path("~kubuntu-ci/+archive/ubuntu/#{type}")
    sources = ppa.getPublishedSources(source_name: options.source,
                                      status: status,
                                      exact_match: true)
    sources.each do |s|
      log.info "-- deleting :: #{s.display_name} --"
      s.requestDeletion!(removal_comment: 'expunge.rb')
    end
  end
end
