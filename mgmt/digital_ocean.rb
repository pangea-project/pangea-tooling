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
require 'net/sftp'
require 'irb'
require 'yaml'

require_relative '../ci-tooling/lib/retry'

client = @client = DropletKit::Client.new(YAML.load_file("#{Dir.home}/.config/pangea-digital-ocean.yaml"))

@id = nil

def image
  @client.snapshots.all.find { |x| x.name == 'jenkins-slave' }
end

def droplet
  return @client.droplets.find(id: @id) if @id
  ret = @client.droplets.all.find { |x| x.name == 'jenkins-slave-deploy' }
  raise "Found a droplet we didn't know about, wtf #{ret}" if ret
  puts 'creating'
  new_droplet = DropletKit::Droplet.new(
    name: 'jenkins-slave-deploy',
    region: 'fra1',
    image: (image&.id || 'ubuntu-16-04-x64'),
    size: '4gb',
    ssh_keys: @client.ssh_keys.all.collect(&:fingerprint),
    private_networking: true
  )
  new_droplet = @client.droplets.create(new_droplet)
  p @id = new_droplet.id
  sleep 2
  new_droplet
end

previous = @client.droplets.all.find { |x| x.name == 'jenkins-slave-deploy' }
if previous
  puts "previous droplet found; deleting: #{previous}"
  client.droplets.delete(id: previous.id)
end

client.droplet_actions.power_on(droplet_id: droplet.id)
10.times do
  p droplet
  # Wait 16*10 seconds for power_on to success, otherwise unwind :(
  break if droplet.status == 'active'
  puts 'waiting for droplet to start'
  sleep(16)
end
if droplet.status != 'active'
  client.droplets.delete(id: droplet.id)
  abort "failed to start #{droplet}"
end

# We can get here with a droplet that isn't actually working as the
# "creation failed" whatever that means..

args = [droplet.public_ip, 'root']

Retry.retry_it(sleep: 8, times: 16) do
  Net::SSH.start(*args) {}
end

Net::SFTP.start(*args) do |sftp|
  Dir.glob("#{__dir__}/digital_ocean/*").each do |file|
    target = "/root/#{File.basename(file)}"
    puts "#{file} => #{target}"
    sftp.upload!(file, target)
  end
end

# Net::SSH would needs lots of code to catch the exit status.
unless system("ssh root@#{droplet.public_ip} bash /root/deploy.sh")
  puts 'deleting droplet'
  client.droplets.delete(id: droplet.id)
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

action = client.droplet_actions.shutdown(droplet_id: droplet.id)
5.times do
  break if action.status == 'completed'
  puts 'shutdown not complete'
  action = client.actions.find(id: action.id)
  sleep(16)
end

action = client.droplet_actions.power_off(droplet_id: droplet.id)
until action.status == 'completed'
  puts 'poweroff not complete'
  action = client.actions.find(id: action.id)
  sleep(16)
end

old_image = image.dup
action = client.droplet_actions.snapshot(droplet_id: droplet.id, name: 'jenkins-slave')
until action.status == 'completed'
  puts 'snapshot not complete'
  action = client.actions.find(id: action.id)
  sleep(16)
end

puts 'deleting old image'
p client.snapshots.delete(id: old_image.id)
puts 'deleting droplet'
p client.droplets.delete(id: droplet.id)
