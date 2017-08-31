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

require 'date'

require_relative '../ci-tooling/lib/jenkins'
require_relative '../lib/digital_ocean/droplet'

client = DigitalOcean::Client.new
droplets = client.droplets.all
nodes = JenkinsApi::Client.new.node.list
dangling = droplets.select do |drop|
  # Droplet needs to not be a known node after 1 hour of existance.
  # The delay is a bit of leeway so we don't accidently delete things
  # that may have just this microsecond be created but not yet in Jenkins.
  # Also since we don't special case the image maintainence job
  # we'd otherwise kill the droplet out from under it (job takes
  # ~30 minutes on a clean run).
  # FTR the datetime condition is that 1 hour before now is greater
  #   (i.e. more recent) than the creation time (i.e. creation time is more
  #   than 1 hour in the past).
  !nodes.include?(drop.name) &&
    (DateTime.now - Rational(1, 24)) > DateTime.iso8601(drop.created_at)
end

warn "Dangling: #{dangling} #{dangling.size}"
dangling.each do |drop|
  name = drop.name
  warn "Deleting #{name}"
  droplet = DigitalOcean::Droplet.from_name(name)
  raise "Failed to delete #{name}" unless droplet.delete
end
