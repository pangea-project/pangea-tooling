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

require_relative 'base'
require 'net/sftp'

class ProjectsFactory
  # Debian specific project factory.
  class L10N < Base
    DEFAULT_URL_BASE = 'git://git.launchpad.net/~kubuntu-packagers/kubuntu-packaging/+git/kde-l10n-common'.freeze

    # FIXME: same as in neon
    # FIXME: needs a writer!
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'kde-l10n'
    end

    private

    def from_string(str)
      stable_path = "/home/ftpubuntu/stable/applications/#{str}/src/kde-l10n/".freeze
      unstable_path = "/home/ftpubuntu/unstable/applications/#{str}/src/kde-l10n/".freeze
      Net::SFTP.start('depot.kde.org', 'ftpubuntu') do |sftp|
        output = sftp.dir.glob(stable_path, '**/**.tar.*').map(&:name)
        output ||= sftp.dir.glob(unstable_path, '**/**.tar.*').map(&:name)
        return cleanup_ls(output, str).freeze
      end
    end

    def cleanup_ls(data, str)
      pattern = "(kde-l10n-.*)-#{str}".freeze
      data.collect do |entry|
        match = entry.match(/#{pattern}/)[1] if entry.match(/#{pattern}/)
      end
    end
  end
end
