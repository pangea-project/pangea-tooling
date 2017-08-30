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

require 'logger'
require 'logger/colors'
require 'net/sftp'
require 'irb'
require 'yaml'

require_relative '../lib/digital_ocean/droplet'

DROPLET_NAME = 'jenkins-slave-deploy'.freeze
IMAGE_NAME = 'jenkins-slave'.freeze

logger = @logger = Logger.new(STDERR)

previous = DigitalOcean::Droplet.from_name(DROPLET_NAME)

if previous
  logger.warn "previous droplet found; deleting: #{previous}"
  raise "Failed to delete #{previous}" unless previous.delete
  raise 'Deletion failed apparently' unless Action.wait(retries: 10) do
    Droplet.from_name(DROPLET_NAME).nil?
  end
end

logger.info 'Creating new droplet.'
droplet = DigitalOcean::Droplet.create(DROPLET_NAME, IMAGE_NAME)

# Wait a decent amount for the droplet to start. If this takes very long it's
# no problem.
active = DigitalOcean::Action.wait(retries: 20) do
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

old_image = DigitalOcean::Client.new.snapshots.all.find do |x|
  x.name == IMAGE_NAME
end

droplet.snapshot!(name: IMAGE_NAME).complete! do
  logger.info 'Waiting for snapshot'
end

if old_image
  logger.warn 'deleting old image'
  unless DigitalOcean::Client.new.snapshots.delete(id: old_image.id)
    logger.error 'failed to delete old snapshot'
    # FIXME: beginning needs to handle multiple images and throw away all but the
    #   newest
  end
end

logger.warn 'deleting droplet'
logger.error 'failed to delete' unless droplet.delete
deleted = DigitalOcean::Action.wait(retries: 10) do
  DigitalOcean::Droplet.from_name(DROPLET_NAME).nil?
end
raise 'Deletion failed apparently' unless deleted
