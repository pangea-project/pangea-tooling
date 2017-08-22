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

require 'fileutils'
require 'tty/command'

require_relative '../../ci-tooling/lib/apt'

module NCI
  module Snap
    # Helper to publish a snap to the store.
    class Publisher
      SNAPNAME = ENV.fetch('APPNAME')

      def self.install!
        Apt.update || raise
        Apt.install('snapcraft') || raise
      end

      def self.copy_config!
        # Host copies their credentials into our workspace, copy it to where
        # snapcraft looks for them.
        cfgdir = "#{Dir.home}/.config/snapcraft"
        FileUtils.mkpath(cfgdir)
        File.write("#{cfgdir}/snapcraft.cfg", File.read('snapcraft.cfg'))
      end

      def self.run
        install!
        copy_config!

        cmd = TTY::Command.new
        # FIXME: the channels need dynamicism of some form.
        cmd.run("snapcraft push #{SNAPNAME}*.snap --release edge")
      end
    end
  end
end
