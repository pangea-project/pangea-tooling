# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # # Special result variant so we can easily check for the result type.
    # # We currently do not expect that dh_missing is always present so we
    # # need to specialcase it's validity.
    # class DHMissingResult < Result; end

    class DHMissing < Linter
      include BuildLogSegmenter

      def lint(data)
        r = Result.new
        # Sometimes dh lines may start with indentation. It's uncear
        # why that happens.
        data = segmentify(data,
                          /^(\s*)dh_install( .+)?$/,
                          /^(\s*)dpkg-deb: building package.+$/)

        data.each do |line|
          next unless line.strip.start_with?('dh_missing: ')

          r.errors << line
        end
        r.valid = true
        r
      rescue BuildLogSegmenter::SegmentMissingError => e
        # Older logs may not contain the dh_missing at all!
        # TODO: revise this and always expect dh_missing to actually be run.
        puts "#{self.class}: in log #{e.message}"
        r
      end
    end
  end
end
