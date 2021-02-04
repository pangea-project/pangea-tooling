# frozen_string_literal: true
#
# Copyright (C) 2016 Rohan Garg <rohan@garg.io>
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
require_relative 'common'

require 'net/sftp'

class ProjectsFactory
  # Debian specific project factory.
  class KDEL10N < Base
    include ProjectsFactoryCommon
    DEFAULT_URL_BASE = 'https://github.com/shadeslayer/kde-l10n-common'

    # FIXME: same as in neon
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'kde-l10n'
    end

    private

    def params(str)
      name = str.split('/')[-1]
      default_params.merge(
        name: name,
        component: 'kde-l10n',
        url_base: self.class.url_base
      )
    end

    class << self
      def ls(base)
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)
        @list_cache[base] = check_ftp(base).freeze
      end

      private

      def check_ftp(base)
        stable_path =
          "/home/ftpubuntu/stable/applications/#{base}/src/kde-l10n/"
        unstable_path =
          "/home/ftpubuntu/unstable/applications/#{base}/src/kde-l10n/"
        output = nil
        Net::SFTP.start('depot.kde.org', 'ftpubuntu') do |sftp|
          output = sftp.dir.glob(stable_path, '**/**.tar.*').map(&:name)
          output ||= sftp.dir.glob(unstable_path, '**/**.tar.*').map(&:name)
        end
        cleanup_ls(output, base)
      end

      def cleanup_ls(data, str)
        pattern = "(kde-l10n-.*)-#{str}"
        data.collect do |entry|
          entry.match(/#{pattern}/)[1] if entry =~ /#{pattern}/
        end
      end
    end
  end
end
