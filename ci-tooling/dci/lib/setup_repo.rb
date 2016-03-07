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
    setup_backports! unless ENV.fetch('DIST') == 'unstable'

    repos = %w(frameworks plasma odroid)
    repos += %w(backports qt5) if ENV.fetch('DIST') == 'stable'

    repos.each do |repo|
      debline = "deb http://dci.ds9.pub:8080/#{repo} #{ENV.fetch('DIST')} main"
      raise 'adding repo failed' unless Apt::Repository.add(debline)
    end
    key = "#{__dir__}/../dci_apt.key"
    raise 'Failed to import key' unless Apt::Key.add(key)

    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }
    raise 'failed to upgrade' unless Apt.dist_upgrade
  end

  def setup_backports!
    # Because we have no /etc/lsb_release
    Apt.install('lsb-release')
    release = `lsb_release -sc`.strip

    debline = "deb http://ftp.debian.org/debian #{release}-backports main"
    raise 'adding backports failed' unless Apt::Repository.add(debline)
    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }

    # Need a newer uscan
    packages = ["devscripts/#{release}-backports",
                "pbuilder/#{release}-backports"]
    Apt.install(packages)
  end
end
