#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require 'droplet_kit'
require 'logger'
require 'logger/colors'
require 'net/sftp'
require 'irb'
require 'yaml'

require_relative '../ci-tooling/lib/retry'

class Client < DropletKit::Client
  def initialize
    super(YAML.load_file("#{Dir.home}/.config/pangea-digital-ocean.yaml"))
  end
end

class Droplet
  attr_accessor :client
  attr_accessor :id

  class << self
    def from_name(name, client = Client.new)
      drop = client.droplets.all.find { |x| x.name == name }
      return drop unless drop
      new(drop, client)
    end

    def exist?(name, client = Client.new)
      client.droplets.all.any? { |x| x.name == name }
    end

    def create(client = Client.new)
      name = 'jenkins-slave-deploy'
      image = client.snapshots.all.find { |x| x.name == 'jenkins-slave' }

      raise "Found a droplet with name #{name} WTF" if exist?(name, client)
      new_droplet = DropletKit::Droplet.new(
        name: name,
        region: 'fra1',
        image: (image&.id || 'ubuntu-16-04-x64'),
        size: '4gb',
        ssh_keys: client.ssh_keys.all.collect(&:fingerprint),
        private_networking: true
      )
      new(client.droplets.create(new_droplet), client)
    end
  end

  def initialize(droplet_or_id, client)
    @client = client
    @id = droplet_or_id
    @id = droplet_or_id.id if droplet_or_id.is_a?(DropletKit::Droplet)
  end

  def method_missing(meth, *args, **kwords)
    return missing_action(meth, *args, **kwords) if meth.to_s[-1] == '!'
    res = resource
    if res.respond_to?(meth)
      # The droplet_kit resource mapping crap is fairly shitty and doesn't
      # manage to handle kwords properly, pack it into a ruby <=2.0 style array.
      argument_pack = []
      argument_pack += args unless args.empty?
      argument_pack << kwords unless kwords.empty?
      return res.send(meth, *argument_pack) if res.respond_to?(meth)
    end
    p meth, args, { id: id }.merge(kwords)
    client.droplets.send(meth, *args, **{ id: id }.merge(kwords))
  end

  private

  def missing_action(name, *args, **kwords)
    name = name.to_s[0..-2].to_sym # strip trailing !
    action = client.droplet_actions.send(name, *args,
                                         **{ droplet_id: id }.merge(kwords))
    Action.new(action, client)
  end

  def resource
    client.droplets.find(id: id)
  end

  def to_str
    id
  end
end

class Action
  attr_accessor :client
  attr_accessor :id

  class << self
    def wait(sleep_for: 16, retries: 100_000, error: nil)
      broken = false
      retries.times do
        if yield
          broken = true
          break
        end
        sleep(sleep_for)
      end
      raise error if error && !broken
      broken
    end
  end

  def initialize(action_or_id, client)
    @client = client
    @id = action_or_id
    @id = action_or_id.id if action_or_id.is_a?(DropletKit::Action)
  end

  def until_status(state)
    count = 0
    until resource.status == state
      yield count
      count += 1
      sleep 16
    end
  end

  def complete!(&block)
    until_status('completed', &block)
  end

  def method_missing(meth, *args, **kwords)
    # return missing_action(action, *args) if meth.to_s[-1] == '!'
    res = resource
    if res.respond_to?(meth)
      # The droplet_kit resource mapping crap is fairly shitty and doesn't
      # manage to handle kwords properly, pack it into a ruby <=2.0 style array.
      argument_pack = []
      argument_pack += args unless args.empty?
      argument_pack << kwords unless kwords.empty?
      return res.send(meth, *argument_pack) if res.respond_to?(meth)
    end
    super
  end

  private

  def resource
    client.actions.find(id: id)
  end
end

logger = @logger = Logger.new(STDERR)

previous = Droplet.from_name('jenkins-slave-deploy')

if previous
  logger.warn "previous droplet found; deleting: #{previous}"
  raise "Failed to delete #{previous}" unless previous.delete
  raise 'Deletion failed apparently' unless Action.wait(retries: 10) do
    Droplet.from_name('jenkins-slave-deploy').nil?
  end
end

logger.info 'Creating new droplet.'
droplet = Droplet.create

# Wait a decent amount for the droplet to start. If this takes very long it's
# no problem.
active = Action.wait(retries: 20) do
  logger.info 'Waiting for droplet to start'
  droplet.status == 'active'
end

unless active
  droplet.delete
  raise "failed to start #{droplet}"
end

# We can get here with a droplet that isn't actually working as the
# "creation failed" whatever that means..
# FIXME: not sure how though (:

args = [droplet.public_ip, 'root']

Retry.retry_it(sleep: 8, times: 16) do
  logger.info "waiting for SSH to start #{args}"
  Net::SSH.start(*args) {}
end

Net::SFTP.start(*args) do |sftp|
  Dir.glob("#{__dir__}/digital_ocean/*").each do |file|
    target = "/root/#{File.basename(file)}"
    logger.info "#{file} => #{target}"
    sftp.upload!(file, target)
  end
end

# Net::SSH would needs lots of code to catch the exit status.
unless system("ssh root@#{droplet.public_ip} bash /root/deploy.sh")
  logger.warn 'deleting droplet'
  droplet.delete
  raise
end
system("ssh root@#{droplet.public_ip} shutdown now")
# Net::SSH.start(*args) do |ssh|
#   ssh.exec!('/root/deploy.sh') do |channel, stream, data|
#     io = stream == :stdout ? STDOUT : STDERR
#     io.print(data)
#     io.flush
#   end
# end

droplet.shutdown!.complete! do |times|
  break if times >= 10
  logger.info 'Waiting for shutdown'
end

droplet.power_off!.complete! do
  logger.info 'Waiting for power off'
end

old_image = Client.new.snapshots.all.find { |x| x.name == 'jenkins-slave' }

droplet.snapshot!(name: 'jenkins-slave').complete! do
  logger.info 'Waiting for snapshot'
end

logger.warn 'deleting old image'
unless Client.new.snapshots.delete(id: old_image.id)
  logger.error 'failed to delete old snapshot'
  # FIXME: beginning needs to handle multiple images and throw away all but the
  #   newest
end

logger.warn 'deleting droplet'
logger.error 'failed to delete' unless droplet.delete
raise 'Deletion failed apparently' unless Action.wait(retries: 10) do
  Droplet.from_name('jenkins-slave-deploy').nil?
end
