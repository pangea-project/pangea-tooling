# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
# Copyright (C) 2021 Scarlett Moore <sgmoore@kde.org>
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

require_relative '../../lib/apt'
require_relative '../../lib/dpkg'
require_relative '../../lib/os'
require_relative '../../lib/retry'
require_relative '../../lib/dci'

# DCI specific helpers.
module DCI
  module_function

  def setup_repo!
    @series = ENV.fetch('SERIES')
    @release_type = ENV.fetch('RELEASE_TYPE')
    @release = ENV.fetch('RELEASE')
    @prefix = DCI.aptly_prefix(@release_type)
    @dist = DCI.series_release(@release, @series)
    @components = DCI.components_by_release(DCI.get_release_data(@release_type, @release))
    key = "#{__dir__}/../dci_apt.key"
    raise 'Failed to import key' unless Apt::Key.add(key)
    raise 'failed to update' unless Apt.update
    raise 'failed to upgrade' unless Apt.upgrade

    setup_i386!
    setup_backports! unless @release_type == 'zynthbox' 
    add_repos(@prefix, @dist, @components)
  end

  def setup_i386!
    system('dpkg --add-architecture i386')
  end

  def setup_backports!
    debline = 'deb http://deb.debian.org/debian stable-backports main'
    raise 'adding backports failed' unless Apt::Repository.add(debline)
    raise 'update failed' unless Apt.update

    Retry.retry_it(times: 5, sleep: 2) do
      raise 'backports upgrade failed' unless Apt.upgrade("-t=stable-backports")
    end
  end

  def add_repos(prefix, dist, components)
    components = components.join(' ')
    debline = "deb http://dci.ds9.pub/#{prefix} #{dist} #{components}"
    Retry.retry_it(times: 5, sleep: 2) do
      raise 'adding repo failed' unless Apt::Repository.add(debline)
    end
  end
end
