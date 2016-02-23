#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require 'fileutils'
require 'git'
require 'json'
require 'logger'
require 'logger/colors'
require 'tmpdir'

require 'thwait'

require_relative '../lib/optparse'
require_relative '../lib/projects/factory/neon'
require_relative '../lib/retry'

origins = []
target = nil
create = true

parser = OptionParser.new do |opts|
  opts.banner =
    "Usage: #{opts.program_name} --origin ORIGIN --target TARGET GIT-SUBDIR"

  opts.on('-o ORIGIN_BRANCH', '--origin BRANCH',
          'Branch to merge or branch from. Multiple origins can be given',
          'they will be tried in the sequence they are specified.',
          'If one origin does not exist in a repository the next origin',
          'is tried instead.', 'EXPECTED') do |v|
    origins += v.split(',')
  end

  opts.on('-t TARGET_BRANCH', '--target BARNCH',
          'The target branch to merge into.', 'EXPECTED') do |v|
    target = v
  end

  opts.on('--[no-]create',
          'Create the target branch if it does not exist yet.' \
          ' [default: on]') do |v|
    create = v
  end
end
parser.parse!

COMPONENT = ARGV.last || nil
ARGV.clear

unless parser.missing_expected.empty?
  puts "Missing expected arguments: #{parser.missing_expected.join(', ')}\n\n"
  abort parser.help
end
if target.nil? || target.empty?
  abort "target must not be empty!\n" + parser.help
end
if COMPONENT.nil? || COMPONENT.empty?
  abort "COMPONENT must not be empty!\n" + parser.help
end

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

logger.warn "For component #{COMPONENT} we are going to merge #{origins}" \
            " into #{target}."
if create
  logger.warn "We are going to create missing #{target} branches from a" \
              ' matching origin.'
else
  logger.warn "We are NOT going to create missing #{target} branches."
end
logger.warn 'Pushing does not happen until after you had a chance to inspect' \
            ' the results.'

logger.warn "#{origins.join('|')} ⇢ #{target}"

repos = ProjectsFactory::Neon.ls.select { |r| r.start_with?(COMPONENT) }
logger.debug "repos: #{repos}"

nothing_to_push = []
Dir.mktmpdir('stabilizer') do |tmpdir|
  Dir.chdir(tmpdir)
  repos.each do |repo|
    log = Logger.new(STDOUT)
    log.level = Logger::INFO
    log.progname = repo
    log.info '----------------------------------'

    git = if !File.exist?(repo)
            Git.clone("neon:#{repo}", repo)
          else
            Git.open(repo)
          end

    git.config('merge.dpkg-mergechangelogs.name',
               'debian/changelog merge driver')
    git.config('merge.dpkg-mergechangelogs.driver',
               'dpkg-mergechangelogs -m %O %A %B %A')

    acted = false
    origins.each do |origin|
      unless git.is_branch?(origin)
        log.error "origin branch '#{origin}' not found"
        next
      end
      if git.is_branch?(target)
        git.checkout(origin)
        git.checkout(target)
        log.warn "Merging #{origin} ⇢ #{target}"
        git.merge(origin, "Merging #{origin} into #{target}\n\nNOCI")
      elsif create
        git.checkout(origin)
        log.warn "Creating #{origin} ⇢ #{target}"
        git.checkout(target, new_branch: true)
      end
      acted = true
      break
    end
    nothing_to_push << repo unless acted
  end

  repos -= nothing_to_push
  logger.progname = ''
  logger.info "The processed repos are in #{Dir.pwd} - Please verify."
  logger.info "The following repos will have #{target} pushed:\n" \
              " #{repos.join(', ')}"
  loop do
    logger.info 'Please type \'c\' to continue'
    break if gets.chop.casecmp('c')
  end

  repos.each do |repo|
    logger.info "pushing #{repo}"
    git = Git.open(repo)
    git.push('origin', target)
  end
end
