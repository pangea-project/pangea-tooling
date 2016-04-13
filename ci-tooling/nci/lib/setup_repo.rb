# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'
require_relative '../../lib/retry'
require_relative 'mirrors'

# Neon CI specific helpers.
module NCI
  module_function

  def setup_repo!
    # switch_mirrors!
    add_repo!
    if ENV.fetch('TYPE') == 'testing'
      ENV['TYPE'] = 'release'
      add_repo!
    end
    Retry.retry_it(times: 5, sleep: 4) { raise unless Apt.update }
    raise 'failed to install deps' unless Apt.install(%w(pkg-kde-tools))
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
      Apt::Key.add('http://archive.neon.kde.org/public.key')
      raise 'Failed to import key' unless $? == 0
    end

    def switch_mirrors!
      file = '/etc/apt/sources.list'
      sources = File.read(file)
      sources = sources.gsub('http://archive.ubuntu.com/ubuntu/', Mirrors.best)
      File.write(file, sources)
    end
  end
end
