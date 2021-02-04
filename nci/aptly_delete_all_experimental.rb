#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2019 Harald Sitter <sitter@kde.org>
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
require 'net/ssh/gateway'
require 'ostruct'
require 'optparse'
require 'tty-prompt'
require 'tty-spinner'

require_relative '../lib/aptly-ext/remote'
require_relative '../lib/nci'

options = OpenStruct.new
options.repos ||= ["experimental_#{NCI.current_series}"]

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name}"
end
parser.parse!

abort parser.help if options.repos.empty?

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

# SSH tunnel so we can talk to the repo
Aptly::Ext::Remote.neon do
  log.info 'APTLY'
  Aptly::Repository.list.each do |repo|
    next unless options.repos.include?(repo.Name)

    packages = repo.packages

    log.info format('Deleting packages from repo %<name>s: %<pkgs>s %<suffix>s',
                    name: repo.Name,
                    pkgs: packages.first(50).to_s,
                    suffix: packages.size > 50 ? ' and more ...' : '')

    abort if TTY::Prompt.new.no?('Are you absolutely sure about this?')

    spinner = TTY::Spinner.new('[:spinner] :title')

    spinner.update(title: "Deleting packages from #{repo.Name}")
    spinner.run { repo.delete_packages(packages) }

    spinner.update(title: "Re-publishing #{repo.Name}")
    spinner.run { repo.published_in.each(&:update!) }
  end
end
