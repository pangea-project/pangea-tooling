# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require 'net/http'
require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'
require_relative '../../lib/retry'

# Neon CI specific helpers.
module NCI
  # NOTE: we talk to squid directly to reduce forwarding overhead, if we routed
  #   through apache we'd be spending between 10 and 25% of CPU on the forward.
  PROXY_URI = URI::HTTP.build(host: 'apt.cache.pangea.pub', port: 8000)

  module_function

  def add_repo_key!
    Retry.retry_it(times: 3, sleep: 8) do
      if Apt::Key.add('444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D')
        return
      end
      raise 'Failed to import key'
    end
  end

  def setup_repo!
    setup_proxy!
    add_repo!
    if ENV.fetch('TYPE') == 'testing'
      ENV['TYPE'] = 'release'
      add_repo!
    end
    Retry.retry_it(times: 5, sleep: 4) { raise unless Apt.update }
    raise 'failed to install deps' unless Apt.install(%w[pkg-kde-tools])
  end

  def setup_proxy!
    puts "Set proxy to #{PROXY_URI}"
    File.write('/etc/apt/apt.conf.d/proxy',
               "Acquire::http::Proxy \"#{PROXY_URI}\";")
  end

  class << self
    private

    def add_repo!
      debline = format('deb http://archive.neon.kde.org/%s %s main',
                       ENV.fetch('TYPE'),
                       LSB::DISTRIB_CODENAME)
      Retry.retry_it(times: 5, sleep: 4) do
        raise 'adding repo failed' unless Apt::Repository.add(debline)
      end
      add_repo_key!
    end
  end
end
