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

require 'aptly'
require 'logger'
require 'logger/colors'
require 'tty/prompt'
require 'net/ssh/gateway'
require 'ostruct'
require 'optparse'

require_relative '../lib/aptly-ext/remote'

options = OpenStruct.new
parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} SOURCENAME"

  opts.on('-r REPO', '--repo REPO',
          'Repo (e.g. unstable_focal) to delete from [can be used >1 time]') do |v|
    options.repos ||= []
    options.repos << v.to_s
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote (auto-defaults to neon)') do |v|
    options.gateway = URI(v)
  end

  opts.on('-a', '--all', 'all repos') do |v|
    options.all = v
  end
end
parser.parse!

abort parser.help unless ARGV[0] && (options.repos or options.all)
options.name = ARGV[0]

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

# SSH tunnel so we can talk to the repo. For extra flexibility this is not
# neon specific but can get any gateway.
with_connection = Proc.new do |&block|
  if options.gateway
    Aptly::Ext::Remote.connect(options.gateway, &block)
  else
    Aptly::Ext::Remote.neon(&block)
  end
end

with_connection.call do
  log.info 'APTLY'
  Aptly::Repository.list.each do |repo|
    next unless options.all or options.repos.include?(repo.Name)

    # Query all relevant packages.
    # Any package with source as source.
    query = "($Source (#{options.name}))"
    # Or the source itself
    query += " | (#{options.name} {source})"
    query = "#{options.name}"
    packages = repo.packages(q: query).compact.uniq
    next if packages.empty?

    log.info "Deleting packages from repo #{repo.Name}: #{packages}"
    if TTY::Prompt.new.no?("Deleting packages, do you want to continue?")
      abort
    end
    repo.delete_packages(packages)
    repo.published_in.each(&:update!)
  end
end
