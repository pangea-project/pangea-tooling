# frozen_string_literal: true
#
# Copyright (C) 2018-2019 Harald Sitter <sitter@kde.org>
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

require 'tmpdir'
require 'tty/command'

require_relative 'identifier'

module NCI
  module Snap
    # Takes a snapcraft channel id, downloads the snap, and unpacks it into
    # /snap
    class Unpacker
      attr_reader :snap

      def initialize(id_str)
        @snap = Identifier.new(id_str)
        @cmd = TTY::Command.new(uuid: false)
      end

      def unpack
        snap_dir = "/snap/#{snap.name}"
        target_dir = "#{snap_dir}/current"
        Dir.mktmpdir do |tmpdir|
          file = download_into(tmpdir)

          FileUtils.mkpath(snap_dir) if Process.uid.zero?
          @cmd.run('unsquashfs', '-d', target_dir, file)
        end
        target_dir
      end

      private

      def download_into(dir)
        @cmd.run('snap', 'download', "--channel=#{snap.risk}", snap.name,
                 chdir: dir)
        snaps = Dir.glob("#{dir}/*.snap")
        unless snaps.size == 1
          raise "Failed to find one snap in #{dir}: #{snaps}"
        end

        snaps[0]
      end
    end
  end
end
