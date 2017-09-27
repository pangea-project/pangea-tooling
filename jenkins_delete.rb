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

require 'date'
require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/queue'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'ci-tooling/lib/retry'
require_relative 'lib/jenkins/job'

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_delte.rb 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

e.g.
  • All build jobs for vivid and utopic:
    '^(vivid|utopic)_.*_.*'

  • All unstable builds:
    '^.*_unstable_.*'

  • All jobs:
    '.*'
  EOS
end.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'poll'
  l.level = Logger::INFO
end

raise 'Need ruby pattern as argv0' if ARGV.empty?
pattern = Regexp.new(ARGV[0])
@log.info pattern

def ditch_child(element)
  element.children.remove if element&.children
end

def mangle_xml(xml)
  doc = Nokogiri::XML(xml)
  ditch_child(doc.at('*/triggers'))
  ditch_child(doc.at('*/builders'))
  ditch_child(doc.at('*/publishers'))
  ditch_child(doc.at('*/buildWrappers'))
  doc.to_xml
end

job_names = Jenkins.job.list_all.select { |name| pattern.match(name) }

# First wipe and disable them.
# In an effort to improve reliability of delets we attempt to break dep
# chains as much as possible by breaking the job configs to force unlinks of
# downstreams.
job_name_queue = Queue.new(job_names)
BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    job = Jenkins::Job.new(name)
    @log.info "Mangling #{name}"
    Retry.retry_it(times: 5) do
      job.disable!
    end
    Retry.retry_it(times: 5) do
      job.update(mangle_xml(job.get_config))
    end
    begin
      job.wipe!
    rescue
      @log.warn "Wiping of #{name} failed. Continue without wipe."
    end
  end
end

# Once all are disabled, proceed with deleting.
job_name_queue = Queue.new(job_names)
BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    @log.info "Deleting #{name}"
    job = Jenkins::Job.new(name)
    job.delete!
  end
end
