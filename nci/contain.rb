#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 7 * 60 * 60 # 7 hours.

DIST = ENV.fetch('DIST')
JOB_NAME = ENV.fetch('JOB_NAME')
PWD_BIND = ENV.fetch('PWD_BIND', Dir.pwd)

# Whitelist a bunch of Jenkins variables for consumption inside the container.
whitelist = %w[BUILD_CAUSE ROOT_BUILD_CAUSE RUN_DISPLAY_URL JOB_NAME
               PANGEA_PROVISION_AUTOINST]
whitelist += (ENV['DOCKER_ENV_WHITELIST'] || '').split(':')
ENV['DOCKER_ENV_WHITELIST'] = whitelist.join(':')


# TODO: autogenerate from average build time?
# TODO: maybe we should have a per-source cache that gets shuffled between the
#   master and slave. with private net enabled this may be entirely doable
#   without much of a slow down (if any). also we can then make use of a volume
#   giving us more leeway in storage.
# Whitelist only certain jobs for ccache. With the amount of jobs we
# have we'd need probably >=20G of cache to cover everything, instead only cache
# the longer builds. This way we stand a better chance of having a cache at
# hand as the smaller builds do not kick the larger ones out of the cache.
CCACHE_WHITELIST = %w[
  plasma-desktop
  plasma-workspace
  kio
  kwin
  khtml
  marble
  kdepim-addons
  kdevplatform
].freeze

def default_ccache_dir
  dir = '/var/cache/pangea-ccache-neon'
  return nil unless CCACHE_WHITELIST.any? { |x| JOB_NAME.include?("_#{x}_") }
  return dir if File.exist?(dir) && ENV.fetch('TYPE', '') == 'unstable'
  nil
end

CCACHE_DIR = default_ccache_dir
CONTAINER_NAME = "neon_#{JOB_NAME}"

# TODO: transition away from compat behavior and have contain properly
#       apply pwd_bind all the time?
c = nil
if PWD_BIND != Dir.pwd # backwards compat. Behave as previosuly without pwd_bind
  binds = ["#{Dir.pwd}:#{PWD_BIND}"]
  binds << "#{CCACHE_DIR}:/ccache" if CCACHE_DIR
  c = CI::Containment.new(CONTAINER_NAME,
                          image: CI::PangeaImage.new(:ubuntu, DIST),
                          binds: binds)
else
  c = CI::Containment.new(CONTAINER_NAME,
                          image: CI::PangeaImage.new(:ubuntu, DIST))
end

status_code = c.run(Cmd: ARGV, WorkingDir: PWD_BIND)
exit status_code
