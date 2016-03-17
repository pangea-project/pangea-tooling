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

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/optparse'

class Node
  ONLINE = :online
  OFFLINE = :offline

  class << self
    def states
      [ONLINE, OFFLINE]
    end

    attr_accessor :target_state
  end

  def initialize(name, client)
    @name = name
    @client = client
  end

  def skip?
    master? || filtered? || already_target_state?
  end

  def toggle!
    @client.toggle_temporarilyOffline(@name, 'Maintenance')
  end

  private

  def target_state
    self.class.target_state
  end

  def master?
    @name == 'master'
  end

  def filtered?
    false # Can be used to filter out specific names
  end

  def state
    @client.is_offline?(@name) ? OFFLINE : ONLINE
  end

  def already_target_state?
    target_state == state
  end

  def to_s
    @name
  end
end

ci_configs = []

parser = OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: #{opts.program_name} --config CONFIG1 --config CONFIG2

Set jenkins instances into maintenance by setting all their slaves offline.
This does not put the instances into maintenance mode, nor does it wait for
the queue to clear!
EOF
  opts.separator('')

  opts.on('-s STATE', '--state STATE', Node.states,
          'Which state to switch to',
          'EXPECTED') do |v|
    Node.target_state = v.to_sym
  end

  opts.on('-c CONFIG', '--config CONFIG',
          'The Pangea jenkins config to load to create api client instances.',
          'These live in $HOME/.config/ usually but can be anywhere.',
          'EXPECTED') do |v|
    ci_configs << v
  end
end
parser.parse!

unless parser.missing_expected.empty?
  puts "Missing expected arguments: #{parser.missing_expected.join(', ')}\n\n"
  abort parser.help
end

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'maintenance'
  l.level = Logger::INFO
end

cis = ci_configs.collect do |config|
  JenkinsApi::Client.new(config_file: config)
end

cis.each do |ci|
  if Node.target_state == Node::OFFLINE
    @log.info "Setting system #{ci.server_ip} into maintenance mode."
    ci.system.quiet_down
  end
  node_client = ci.node
  node_client.list.each do |name|
    node = Node.new(name, node_client)
    next if node.skip?
    @log.info "Taking #{node} on #{ci.server_ip} #{Node.target_state}"
    node.toggle!
  end
  if Node.target_state == Node::ONLINE
    @log.info "Taking system #{ci.server_ip} out of maintenance mode."
    ci.system.cancel_quiet_down
  end
end
