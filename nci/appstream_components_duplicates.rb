#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2019-2022 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'date'
require 'faraday'
require 'json'
require 'open-uri'
require 'pp'
require 'tty/command'
require 'yaml'
require 'concurrent'

require_relative '../lib/apt'
require_relative 'lib/setup_repo'

# Simple wrapper around an appstream id and its likely permutations that may
# indicate a dupe. e.g. org.kde.foo => [org.kde.foo.desktop, foo.desktop, foo]
class ID
  attr_reader :active
  attr_reader :permutations

  def initialize(id)
    @active = id

    @permutations = [desktop_permutation,
                     rdn_permutation(desktop_permutation),
                     rdn_permutation(id)]
    @permutations.uniq!
    @permutations.compact!
    @permutations.reject! { |x| x == id }
  end

  private

  def desktop_permutation
    return active.gsub('.desktop', '') if active.end_with?('.desktop')

    active + '.desktop'
  end

  def rdn_permutation(id)
    return "org.kde.#{id}" if id.count('.') < 2 # no RDN id

    offset = id.end_with?('.desktop') ? -2..-1 : -1..-1
    parts = id.split('.')[offset]
    parts.join('.')
  end
end

# class Snapd
#   attr_reader :connection

#   def initialize
#     @connection = Faraday.new('unix:/') do |c|
#       c.adapter :excon, socket: '/run/snapd.socket'
#     end
#   end

#   def contains?(id)
#     response = connection.get("/v2/find?common-id=#{id}")
#     return false unless response.status == 200

#     data = JSON.parse(response.body)
#     return false unless data['status'] == 'OK'

#     result = data['result']
#     return false if result.empty?

#     result.any? { |snap| snap['common-ids']&.include?(id) }
#   end
# end

if $PROGRAM_NAME == __FILE__
  def puts(str = '')
    print(str + "\n") # Write newline one go lest they get messed by threads.
  end

  NCI.setup_repo!

  Retry.retry_it(times: 3) { Apt.update || raise }
  Retry.retry_it(times: 3) { Apt.install('appstream') || raise }
  Retry.retry_it(times: 3) { Apt.update || raise }

  if Dir.glob('/var/lib/app-info/yaml/*').empty?
    raise "Seems appstream cache didn't generate/update?"
  end

  # Get our known ids from the raw data. This way appstreamcli cannot override
  # what we see. Also we know which ones are our components as opposed to ones
  # from other repos (i.e. ubuntu)
  data = nil
  Retry.retry_it(times: 3) do
    data = URI.open("https://origin.archive.neon.kde.org/user/dists/#{ENV.fetch('DIST')}/main/dep11/Components-amd64.yml").read
  end

  docs = []
  YAML.load_stream(data) do |doc|
    docs << doc
  end

  raise "dep11 file looks malformed #{docs}" if docs.size < 2

  description = docs.shift
  pp description
  created = DateTime.parse(description.fetch('Time'))
  if (DateTime.now - created).to_i >= 60
    # KF5 releases are monthly, so getting no appstream changes for two months
    # is entirely impossible. Guard against broken dep11 data by making sure it
    # is not too too old. Not ideal, but noticing after two months is better than
    # not at all.
    raise 'Appstream cache older than 60 days what gives?'
  end

  # all IDs we know except for ones with a merge rule (e.g
  # `Merge: remove-component` as generated from removed-components.json)
  # TODO: we may also want to bump !`Type: desktop-application` because we also
  #   describe libraries and so forth, those aren't necessarily a problem as
  #   discover doesn't display them. This needs investigation though!
  ids = docs.collect { |x| x['Merge'] ? nil : x['ID'] }
  ids = ids.uniq.compact
  ids = ids.collect { |x| ID.new(x) }
  
  # Some apps have changed IDs and list the old ones as Provides so get a list of those
  provides = docs.collect { |x| x['Provides'] }
  provides = provides.select { |x| x.class == Hash && x.key?('ids') }
  provides = provides.collect { |x| x['ids'] }
  provides = provides.flatten
  puts "List of old IDs given by apps: #{provides}"

  # appstreamcli can exhaust allowed open files, put strict limits on just how
  # much we'll thread it to avoid this problem.
  pool = Concurrent::ThreadPoolExecutor.new(
    min_threads: 2,
    max_threads: Concurrent.processor_count,
    max_queue: 16,
    fallback_policy: :caller_runs
  )

  missing = Concurrent::Array.new
  blacklist = Concurrent::Array.new

  puts '---------------'
  promises = ids.collect do |id|
    Concurrent::Promise.execute(executor: pool) do
      cmd = TTY::Command.new(printer: :null)
      ret = cmd.run!('appstreamcli', 'dump', id.active)
      unless ret.success?
        puts "!! #{id.active} should be available but it is not!"
        puts '   Maybe it is incorrectly blacklisted?'
        missing << id.active
      end

      id.permutations.each do |permutation|
        ret = cmd.run!('appstreamcli', 'dump', permutation)
        if ret.success?
          puts "#{id.active} also has permutation: #{permutation}"
          blacklist << permutation unless provides.include?(permutation)
        end
      end
    end
  end
  promises.collect(&:wait!)
  puts '---------------'

  exit 0 if blacklist.empty? && missing.empty?

  unless blacklist.empty?
    puts <<~DESCRIPTION
============================
There are unexpected duplicates!
These usually happen when a component changes name during its life time and
is now provided by multiple repos under different names.
For example let's say org.kde.kbibtex is in Ubuntu but the developers have since
changed to org.kde.kbibtex.desktop. In neon we have the newer version so our
dep11 data will provide org.kde.kbibtex.desktop while ubuntu's dep11 will
still provide org.kde.kbibtex. Appstream doesn't know that they are the same
so both would show up if you search for bibtex in discover.

To solve this problem we'll want to force the old names removed by adding them
to our removed-components.json

Before doing this please make sure which component is the current one and that
the other one is in fact a duplicate that needs removing! When in in doubt: ask.

https://community.kde.org/Neon/Appstream#Duplicated_Components

    DESCRIPTION

    puts 'REVIEW CAREFULLY! Here is the complete blacklist array'
    puts JSON.generate(blacklist)
    2.times { puts }
  end

  unless missing.empty?
    puts <<~DESCRIPTION
============================
There are components missing from the local cache!
This can mean that they are in the removed-components.json even though
we still actively provide them. This needs manual investigation.
The problem simply is that our raw-dep11 data contained the components but
appstreamcli does not know about them. This either means appstream is broken
somehow or it was told to ignore the components. Bet check
removed-components.json for a start.

    DESCRIPTION

    puts JSON.generate(missing)
    2.times { puts }
  end

  exit 1
end
