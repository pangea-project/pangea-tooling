# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

require_relative 'unpacker'

module NCI
  module Snap
    # Util stuff fro snapcraft itself.
    module Snapcraft
      def self.install
        # Taken from https://github.com/kenvandine/gnome-3-28-1804/blob/master/Dockerfile
        # Requires snapd to already be installed!

        # Special hack to install snapcraft from snap but without even having a
        # running snapd. This only works because snapcraft is a classic snap and
        # rpath'd accordingly.

        # This is not under test because it's fancy scripting and nothing more.

        Unpacker.new('core').unpack
        Unpacker.new('snapcraft').unpack

        wrapper = open('https://raw.githubusercontent.com/snapcore/snapcraft/b292b64d74b643e2ddb3c1ac3f6d6a0bb9baffee/docker/bin/snapcraft-wrapper')
        File.write('/usr/bin/snapcraft', wrapper.read)
        File.chmod(0o744, '/usr/bin/snapcraft')
      end
    end
  end
end
