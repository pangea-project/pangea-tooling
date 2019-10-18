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

require 'net/ssh'

require_relative '../lib/aptly-ext/remote'
require_relative '../lib/aptly-ext/repo_cleaner'

# SSH tunnel so we can talk to the repo
Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 15 * 60)

socket_uri = URI('ssh://aptly@localhost/home/aptly/aptly.socket')
Aptly::Ext::Remote.connect(socket_uri) do
  # Perhaps somewhat unfortunately the cleaner runs on repo names rather than
  # objects, so we'll simply break down the objects to their names
  names = Aptly::Repository.list.collect(&:Name)

  RepoCleaner.clean(names, keep_amount: 8)
end

puts 'Finally cleaning out database...'
Net::SSH.start('localhost', 'aptly') do |ssh|
  # Set XDG_RUNTIME_DIR so we can find our dbus socket.
  ssh.exec!(<<-COMMAND)
XDG_RUNTIME_DIR=/run/user/`id -u` systemctl --user start aptly_db_cleanup
  COMMAND
end
puts 'All done!'
