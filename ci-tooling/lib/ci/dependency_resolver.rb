# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2015 Rohan Garg <rohan@kde.org>
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

require_relative '../os'
require_relative '../retry'

module CI
  # Resolves build dependencies and installs them.
  class DependencyResolver
    RESOLVER_BIN = '/usr/lib/pbuilder/pbuilder-satisfydepends'

    resolver_env = {}
    if OS.to_h.include?(:VERSION_ID) && OS::VERSION_ID == '8'
      resolver_env['APTITUDEOPT'] = '--target-release=jessie-backports'
    end
    resolver_env['DEBIAN_FRONTEND'] = 'noninteractive'
    RESOLVER_ENV = resolver_env.freeze

    def self.resolve(dir, bin_only: false)
      raise "Can't find #{RESOLVER_BIN}!" unless File.executable?(RESOLVER_BIN)

      Retry.retry_it(times: 5) do
        opts = []
        opts << '--binary-arch' if bin_only
        opts << '--control' << "#{dir}/debian/control"
        ret = system(RESOLVER_ENV, RESOLVER_BIN, *opts)
        raise 'Failed to satisfy depends' unless ret
      end
    end
  end
end
