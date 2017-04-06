# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
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

# Mobile CI specific helpers.
module DCI
  module_function

  def setup_repo!
    @dist = ENV.fetch('DIST')
    repos = []
    components = []
    setup_i386

    case @dist
    when 'stable'
      setup_backports!
      repos += %w[frameworks plasma kde-applications extras backports qt5]
      repos += %w[odroid] if DPKG::BUILD_ARCH == 'armhf'
      components += %w[main]
    when 'testing', '1703'
      repos += %w[netrunner]
      components += %w[frameworks backports plasma qt5 kde-applications extras]
      components += %w[odroid] unless DPKG::BUILD_ARCH == 'amd64'
      @dist = "netrunner-#{@dist}"
    end

    add_repos(repos, components)

    key = "#{__dir__}/../dci_apt.key"
    raise 'Failed to import key' unless Apt::Key.add(key)

    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }
    raise 'failed to upgrade' unless Apt.dist_upgrade
  end

  def setup_backports!
    # Because we have no /etc/lsb_release
    Apt.install('lsb-release')
    release = `lsb_release -sc`.strip

    debline = "deb http://deb.debian.org/debian #{release}-backports main"
    raise 'adding backports failed' unless Apt::Repository.add(debline)
    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }

    Apt.dist_upgrade("-t=#{release}-backports")
  end

  def setup_i386
    system('dpkg --add-architecture i386')
  end

  def add_repos(repos, components)
    repos.each do |repo|
      debline = "deb http://dci.ds9.pub:8080/#{repo} #{@dist} #{components.join(' ')}"
      raise 'adding repo failed' unless Apt::Repository.add(debline)
    end
  end
end
