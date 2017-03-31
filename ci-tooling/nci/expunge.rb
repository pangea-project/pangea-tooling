#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

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
require_relative '../../lib/aptly-ext/remote'

Aptly::Ext::Remote.neon do
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
    repo.published_in.each(&:update!)
  end
end
