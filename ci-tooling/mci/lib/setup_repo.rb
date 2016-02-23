# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
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
require_relative '../../lib/lsb'
require_relative '../../lib/retry'

# Mobile CI specific helpers.
module MCI
  module_function

  def setup_repo!
    debline = format('deb http://mobile.neon.pangea.pub %s main',
                     LSB::DISTRIB_CODENAME)
    raise 'adding repo failed' unless Apt::Repository.add(debline)
    Apt::Key.add('http://mobile.neon.pangea.pub/Pangea%20CI.gpg.key')
    raise 'Failed to import key' unless $? == 0

    srcline = 'deb %<host>s %<series>s %<pockets>s'
    debline2 = format(srcline,
                      host: if DPKG::BUILD_ARCH == 'armhf'
                              'http://ports.ubuntu.com/ubuntu-ports'
                            else
                              'http://archive.ubuntu.com/ubuntu'
                            end,
                      series: "#{LSB::DISTRIB_CODENAME}-backports",
                      pockets: 'main restricted universe multiverse')
    Apt::Repository.add(debline2)
    Apt::Repository.add('ppa:plasma-phone/ppa')

    Retry.retry_it(times: 5, sleep: 2) { raise unless Apt.update }
    raise 'failed to install deps' unless Apt.install(%w(pkg-kde-tools))
  end
end
